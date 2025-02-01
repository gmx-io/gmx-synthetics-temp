// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../withdrawal/ExecuteWithdrawalUtils.sol";

import "../../nonce/NonceUtils.sol";

import "../GlvVault.sol";
import "../GlvUtils.sol";
import "./GlvWithdrawalStoreUtils.sol";
import "./GlvWithdrawalEventUtils.sol";

library GlvWithdrawalUtils {
    using GlvWithdrawal for GlvWithdrawal.Props;
    using SafeCast for int256;
    using SafeCast for uint256;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.AddressItems;

    struct CreateGlvWithdrawalParams {
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address market;
        address glv;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
        uint256 minLongTokenAmount;
        uint256 minShortTokenAmount;
        bool shouldUnwrapNativeToken;
        uint256 executionFee;
        uint256 callbackGasLimit;
        bytes32[] dataList;
    }

    struct ExecuteGlvWithdrawalParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        GlvVault glvVault;
        Oracle oracle;
        bytes32 key;
        uint256 startingGas;
        address keeper;
    }

    struct ExecuteGlvWithdrawalCache {
        uint256 glvValue;
        uint256 marketCount;
        uint256 oraclePriceCount;
        uint256 marketTokenAmount;
    }

    struct CancelGlvWithdrawalParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        GlvVault glvVault;
        bytes32 key;
        address keeper;
        uint256 startingGas;
        string reason;
        bytes reasonBytes;
    }

    function createGlvWithdrawal(
        DataStore dataStore,
        EventEmitter eventEmitter,
        GlvVault glvVault,
        address account,
        CreateGlvWithdrawalParams memory params
    ) external returns (bytes32) {
        AccountUtils.validateAccount(account);
        GlvUtils.validateGlv(dataStore, params.glv);
        GlvUtils.validateGlvMarket(dataStore, params.glv, params.market, false);

        MarketUtils.validateEnabledMarket(dataStore, params.market);
        MarketUtils.validateSwapPath(dataStore, params.longTokenSwapPath);
        MarketUtils.validateSwapPath(dataStore, params.shortTokenSwapPath);

        address wnt = TokenUtils.wnt(dataStore);
        uint256 wntAmount = glvVault.recordTransferIn(wnt);
        if (wntAmount < params.executionFee) {
            revert Errors.InsufficientWntAmountForExecutionFee(wntAmount, params.executionFee);
        }
        params.executionFee = wntAmount;

        AccountUtils.validateReceiver(params.receiver);

        uint256 glvTokenAmount = glvVault.recordTransferIn(params.glv);

        if (glvTokenAmount == 0) {
            revert Errors.EmptyGlvWithdrawalAmount();
        }

        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawal.Props(
            GlvWithdrawal.Addresses({
                account: account,
                glv: params.glv,
                receiver: params.receiver,
                callbackContract: params.callbackContract,
                uiFeeReceiver: params.uiFeeReceiver,
                market: params.market,
                longTokenSwapPath: params.longTokenSwapPath,
                shortTokenSwapPath: params.shortTokenSwapPath
            }),
            GlvWithdrawal.Numbers({
                glvTokenAmount: glvTokenAmount,
                minLongTokenAmount: params.minLongTokenAmount,
                minShortTokenAmount: params.minShortTokenAmount,
                updatedAtTime: Chain.currentTimestamp(),
                executionFee: params.executionFee,
                callbackGasLimit: params.callbackGasLimit
            }),
            GlvWithdrawal.Flags({shouldUnwrapNativeToken: params.shouldUnwrapNativeToken}),
            params.dataList
        );

        CallbackUtils.validateCallbackGasLimit(dataStore, params.callbackGasLimit);

        uint256 marketCount = GlvUtils.getGlvMarketCount(dataStore, glvWithdrawal.glv());
        uint256 estimatedGasLimit = GasUtils.estimateExecuteGlvWithdrawalGasLimit(
            dataStore,
            glvWithdrawal,
            marketCount
        );
        uint256 oraclePriceCount = GasUtils.estimateGlvWithdrawalOraclePriceCount(
            marketCount,
            params.longTokenSwapPath.length + params.shortTokenSwapPath.length
        );
        GasUtils.validateExecutionFee(dataStore, estimatedGasLimit, params.executionFee, oraclePriceCount);

        bytes32 key = NonceUtils.getNextKey(dataStore);

        GlvWithdrawalStoreUtils.set(dataStore, key, glvWithdrawal);

        GlvWithdrawalEventUtils.emitGlvWithdrawalCreated(eventEmitter, key, glvWithdrawal);

        return key;
    }

    function executeGlvWithdrawal(
        ExecuteGlvWithdrawalParams memory params,
        GlvWithdrawal.Props memory glvWithdrawal
    ) external {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        GlvWithdrawalStoreUtils.remove(params.dataStore, params.key, glvWithdrawal.account());

        ExecuteGlvWithdrawalCache memory cache;
        cache.marketTokenAmount = _getMarketTokenAmount(params.dataStore, params.oracle, glvWithdrawal);

        // burn GLV tokens before executing withdrawal
        // for both GLV amount and token amounts will be correct inside the receive() function
        // if receiver is a contract
        GlvToken(payable(glvWithdrawal.glv())).burn(address(params.glvVault), glvWithdrawal.glvTokenAmount());
        params.glvVault.syncTokenBalance(glvWithdrawal.glv());

        ExecuteWithdrawalUtils.ExecuteWithdrawalResult memory withdrawalResult = _processMarketWithdrawal(
            params,
            glvWithdrawal,
            cache.marketTokenAmount
        );

        GlvWithdrawalEventUtils.emitGlvWithdrawalExecuted(params.eventEmitter, params.key, glvWithdrawal.account());

        cache.glvValue = GlvUtils.getGlvValue(
            params.dataStore,
            params.oracle,
            glvWithdrawal.glv(),
            true
        );
        GlvEventUtils.emitGlvValueUpdated(
            params.eventEmitter,
            glvWithdrawal.glv(),
            cache.glvValue,
            GlvToken(payable(glvWithdrawal.glv())).totalSupply()
        );

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "outputToken", withdrawalResult.outputToken);
        eventData.addressItems.setItem(1, "secondaryOutputToken", withdrawalResult.secondaryOutputToken);
        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "outputAmount", withdrawalResult.outputAmount);
        eventData.uintItems.setItem(1, "secondaryOutputAmount", withdrawalResult.secondaryOutputAmount);
        CallbackUtils.afterGlvWithdrawalExecution(params.key, glvWithdrawal, eventData);

        cache.marketCount = GlvUtils.getGlvMarketCount(params.dataStore, glvWithdrawal.glv());
        cache.oraclePriceCount = GasUtils.estimateGlvWithdrawalOraclePriceCount(
            cache.marketCount,
            glvWithdrawal.longTokenSwapPath().length + glvWithdrawal.shortTokenSwapPath().length
        );

        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.glvVault,
            params.key,
            glvWithdrawal.callbackContract(),
            glvWithdrawal.executionFee(),
            params.startingGas,
            cache.oraclePriceCount,
            params.keeper,
            glvWithdrawal.receiver()
        );
    }

    function _processMarketWithdrawal(
        ExecuteGlvWithdrawalParams memory params,
        GlvWithdrawal.Props memory glvWithdrawal,
        uint256 marketTokenAmount
    ) private returns (ExecuteWithdrawalUtils.ExecuteWithdrawalResult memory) {

        Withdrawal.Props memory withdrawal = Withdrawal.Props(
            Withdrawal.Addresses({
                account: glvWithdrawal.glv(),
                receiver: glvWithdrawal.receiver(),
                callbackContract: address(0),
                uiFeeReceiver: glvWithdrawal.uiFeeReceiver(),
                market: glvWithdrawal.market(),
                longTokenSwapPath: glvWithdrawal.longTokenSwapPath(),
                shortTokenSwapPath: glvWithdrawal.shortTokenSwapPath()
            }),
            Withdrawal.Numbers({
                minLongTokenAmount: glvWithdrawal.minLongTokenAmount(),
                minShortTokenAmount: glvWithdrawal.minShortTokenAmount(),
                marketTokenAmount: marketTokenAmount,
                updatedAtTime: glvWithdrawal.updatedAtTime(),
                executionFee: 0,
                callbackGasLimit: 0
            }),
            Withdrawal.Flags({shouldUnwrapNativeToken: glvWithdrawal.shouldUnwrapNativeToken()}),
            glvWithdrawal.dataList()
        );

        bytes32 withdrawalKey = NonceUtils.getNextKey(params.dataStore);
        params.dataStore.addBytes32(Keys.WITHDRAWAL_LIST, withdrawalKey);
        WithdrawalEventUtils.emitWithdrawalCreated(
            params.eventEmitter,
            withdrawalKey,
            withdrawal,
            Withdrawal.WithdrawalType.Glv
        );

        Bank(payable(glvWithdrawal.glv())).transferOut(
            glvWithdrawal.market(),
            address(params.glvVault),
            marketTokenAmount
        );
        params.glvVault.syncTokenBalance(glvWithdrawal.market());

        ExecuteWithdrawalUtils.ExecuteWithdrawalParams memory executeWithdrawalParams = ExecuteWithdrawalUtils
            .ExecuteWithdrawalParams({
                dataStore: params.dataStore,
                eventEmitter: params.eventEmitter,
                withdrawalVault: WithdrawalVault(payable(params.glvVault)),
                oracle: params.oracle,
                key: withdrawalKey,
                keeper: params.keeper,
                startingGas: params.startingGas,
                swapPricingType: ISwapPricingUtils.SwapPricingType.Withdrawal
            });

        return ExecuteWithdrawalUtils.executeWithdrawal(executeWithdrawalParams, withdrawal);
    }

    function _getMarketTokenAmount(
        DataStore dataStore,
        Oracle oracle,
        GlvWithdrawal.Props memory glvWithdrawal
    ) internal view returns (uint256) {
        uint256 glvValue = GlvUtils.getGlvValue(
            dataStore,
            oracle,
            glvWithdrawal.glv(),
            false // maximize
        );
        uint256 glvSupply = GlvToken(payable(glvWithdrawal.glv())).totalSupply();
        uint256 glvTokenUsd = GlvUtils.glvTokenAmountToUsd(glvWithdrawal.glvTokenAmount(), glvValue, glvSupply);

        Market.Props memory market = MarketUtils.getEnabledMarket(dataStore, glvWithdrawal.market());
        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            dataStore,
            market,
            oracle.getPrimaryPrice(market.indexToken),
            oracle.getPrimaryPrice(market.longToken),
            oracle.getPrimaryPrice(market.shortToken),
            Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
            true // maximize
        );
        uint256 marketTokenAmount = MarketUtils.usdToMarketTokenAmount(
            glvTokenUsd,
            poolValueInfo.poolValue.toUint256(),
            ERC20(market.marketToken).totalSupply()
        );

        return marketTokenAmount;
    }

    function cancelGlvWithdrawal(CancelGlvWithdrawalParams memory params) external {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(params.dataStore, params.key);
        GlvWithdrawalStoreUtils.remove(params.dataStore, params.key, glvWithdrawal.account());

        params.glvVault.transferOut(
            glvWithdrawal.glv(),
            glvWithdrawal.account(),
            glvWithdrawal.glvTokenAmount(),
            false // shouldUnwrapNativeToken
        );

        GlvWithdrawalEventUtils.emitGlvWithdrawalCancelled(
            params.eventEmitter,
            params.key,
            glvWithdrawal.account(),
            params.reason,
            params.reasonBytes
        );

        EventUtils.EventLogData memory eventData;
        CallbackUtils.afterGlvWithdrawalCancellation(params.key, glvWithdrawal, eventData);

        uint256 marketCount = GlvUtils.getGlvMarketCount(params.dataStore, glvWithdrawal.glv());
        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.glvVault,
            params.key,
            glvWithdrawal.callbackContract(),
            glvWithdrawal.executionFee(),
            params.startingGas,
            GasUtils.estimateGlvWithdrawalOraclePriceCount(
                marketCount,
                glvWithdrawal.longTokenSwapPath().length + glvWithdrawal.shortTokenSwapPath().length
            ),
            params.keeper,
            glvWithdrawal.receiver()
        );
    }
}
