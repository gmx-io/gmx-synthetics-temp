// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../deposit/ExecuteDepositUtils.sol";

import "../../nonce/NonceUtils.sol";

import "../GlvVault.sol";
import "../GlvUtils.sol";
import "./GlvDepositEventUtils.sol";
import "./GlvDepositStoreUtils.sol";
import "./GlvDepositCalc.sol";

library GlvDepositUtils {
    using GlvDeposit for GlvDeposit.Props;
    using Deposit for Deposit.Props;
    using SafeCast for int256;
    using SafeCast for uint256;
    using EventUtils for EventUtils.UintItems;

    struct CreateGlvDepositParams {
        address glv;
        address market;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address initialLongToken;
        address initialShortToken;
        address[] longTokenSwapPath;
        address[] shortTokenSwapPath;
        uint256 minGlvTokens;
        uint256 executionFee;
        uint256 callbackGasLimit;
        bool shouldUnwrapNativeToken;
        bool isMarketTokenDeposit;
        bytes32[] dataList;
    }

    struct CreateGlvDepositCache {
        uint256 marketTokenAmount;
        uint256 initialLongTokenAmount;
        uint256 initialShortTokenAmount;
    }

    struct ExecuteGlvDepositParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        GlvVault glvVault;
        Oracle oracle;
        bytes32 key;
        uint256 startingGas;
        address keeper;
    }

    struct ExecuteGlvDepositCache {
        Market.Props market;
        MarketPoolValueInfo.Props marketPoolValueInfo;
        uint256 marketTokenSupply;
        uint256 receivedMarketTokens;
        uint256 mintAmount;
        uint256 marketCount;
        uint256 oraclePriceCount;
        uint256 glvValue;
        uint256 glvSupply;
    }

    struct CancelGlvDepositParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        GlvVault glvVault;
        bytes32 key;
        address keeper;
        uint256 startingGas;
        string reason;
        bytes reasonBytes;
    }

    address public constant RECEIVER_FOR_FIRST_GLV_DEPOSIT = address(1);

    function createGlvDeposit(
        DataStore dataStore,
        EventEmitter eventEmitter,
        GlvVault glvVault,
        address account,
        CreateGlvDepositParams memory params
    ) external returns (bytes32) {
        AccountUtils.validateAccount(account);
        GlvUtils.validateGlv(dataStore, params.glv);
        GlvUtils.validateGlvMarket(dataStore, params.glv, params.market, true);

        MarketUtils.validateEnabledMarket(dataStore, params.market);

        CreateGlvDepositCache memory cache;

        if (params.isMarketTokenDeposit) {
            // user deposited GM tokens
            if (params.initialLongToken != address(0)) {
                revert Errors.InvalidGlvDepositInitialLongToken(params.initialLongToken);
            }
            if (params.initialShortToken != address(0)) {
                revert Errors.InvalidGlvDepositInitialShortToken(params.initialShortToken);
            }
            if (params.longTokenSwapPath.length > 0 || params.shortTokenSwapPath.length > 0) {
                revert Errors.InvalidGlvDepositSwapPath(
                    params.longTokenSwapPath.length,
                    params.shortTokenSwapPath.length
                );
            }
            cache.marketTokenAmount = glvVault.recordTransferIn(params.market);

            if (cache.marketTokenAmount == 0) {
                revert Errors.EmptyGlvMarketAmount();
            }
        } else {
            MarketUtils.validateSwapPath(dataStore, params.longTokenSwapPath);
            MarketUtils.validateSwapPath(dataStore, params.shortTokenSwapPath);

            if (params.initialLongToken == address(0)) {
                revert Errors.InvalidGlvDepositInitialLongToken(params.initialLongToken);
            }
            if (params.initialShortToken == address(0)) {
                revert Errors.InvalidGlvDepositInitialShortToken(params.initialShortToken);
            }

            // if the initialLongToken and initialShortToken are the same, only the initialLongTokenAmount would
            // be non-zero, the initialShortTokenAmount would be zero
            cache.initialLongTokenAmount = glvVault.recordTransferIn(params.initialLongToken);
            if (params.initialShortToken != params.initialLongToken) {
                cache.initialShortTokenAmount = glvVault.recordTransferIn(params.initialShortToken);
            }
        }

        address wnt = TokenUtils.wnt(dataStore);
        if (params.initialLongToken == wnt) {
            if (cache.initialLongTokenAmount < params.executionFee) {
                revert Errors.InsufficientWntAmountForExecutionFee(cache.initialLongTokenAmount, params.executionFee);
            }
            cache.initialLongTokenAmount -= params.executionFee;
        } else if (params.initialShortToken == wnt) {
            if (cache.initialShortTokenAmount < params.executionFee) {
                revert Errors.InsufficientWntAmountForExecutionFee(cache.initialShortTokenAmount, params.executionFee);
            }
            cache.initialShortTokenAmount -= params.executionFee;
        } else {
            uint256 wntAmount = glvVault.recordTransferIn(wnt);
            if (wntAmount < params.executionFee) {
                revert Errors.InsufficientWntAmountForExecutionFee(wntAmount, params.executionFee);
            }

            params.executionFee = wntAmount;
        }

        if (!params.isMarketTokenDeposit && (cache.initialLongTokenAmount == 0 && cache.initialShortTokenAmount == 0)) {
            revert Errors.EmptyGlvDepositAmounts();
        }

        AccountUtils.validateReceiver(params.receiver);

        GlvDeposit.Props memory glvDeposit = GlvDeposit.Props(
            GlvDeposit.Addresses({
                account: account,
                glv: params.glv,
                receiver: params.receiver,
                callbackContract: params.callbackContract,
                uiFeeReceiver: params.uiFeeReceiver,
                market: params.market,
                initialLongToken: params.initialLongToken,
                initialShortToken: params.initialShortToken,
                longTokenSwapPath: params.longTokenSwapPath,
                shortTokenSwapPath: params.shortTokenSwapPath
            }),
            GlvDeposit.Numbers({
                marketTokenAmount: cache.marketTokenAmount,
                initialLongTokenAmount: cache.initialLongTokenAmount,
                initialShortTokenAmount: cache.initialShortTokenAmount,
                minGlvTokens: params.minGlvTokens,
                updatedAtTime: Chain.currentTimestamp(),
                executionFee: params.executionFee,
                callbackGasLimit: params.callbackGasLimit
            }),
            GlvDeposit.Flags({
                shouldUnwrapNativeToken: params.shouldUnwrapNativeToken,
                isMarketTokenDeposit: params.isMarketTokenDeposit
            }),
            params.dataList
        );

        CallbackUtils.validateCallbackGasLimit(dataStore, params.callbackGasLimit);

        uint256 marketCount = GlvUtils.getGlvMarketCount(dataStore, glvDeposit.glv());
        uint256 estimatedGasLimit = GasUtils.estimateExecuteGlvDepositGasLimit(dataStore, glvDeposit, marketCount);
        uint256 oraclePriceCount = GasUtils.estimateGlvDepositOraclePriceCount(
            marketCount,
            params.longTokenSwapPath.length + params.shortTokenSwapPath.length
        );
        GasUtils.validateExecutionFee(dataStore, estimatedGasLimit, params.executionFee, oraclePriceCount);

        bytes32 key = NonceUtils.getNextKey(dataStore);

        GlvDepositStoreUtils.set(dataStore, key, glvDeposit);

        GlvDepositEventUtils.emitGlvDepositCreated(eventEmitter, key, glvDeposit);

        return key;
    }

    function executeGlvDeposit(
        ExecuteGlvDepositParams memory params,
        GlvDeposit.Props memory glvDeposit
    ) external returns (uint256) {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        GlvDepositStoreUtils.remove(params.dataStore, params.key, glvDeposit.account());

        // should be called before any tokens are minted
        GlvDepositCalc.validateFirstGlvDeposit(params.dataStore, glvDeposit);

        ExecuteGlvDepositCache memory cache;

        cache.receivedMarketTokens = _processMarketDeposit(params, glvDeposit, params.glvVault);

        // glvValue should be calculated after funds are deposited into GM market
        // but before GLV syncs GM token balance for glvValue to account for
        // slightly increased GM market price because of paid fees
        cache.glvValue = GlvUtils.getGlvValue(
            params.dataStore,
            params.oracle,
            glvDeposit.glv(),
            true // maximize
        );
        GlvToken(payable(glvDeposit.glv())).syncTokenBalance(glvDeposit.market());

        cache.glvSupply = GlvToken(payable(glvDeposit.glv())).totalSupply();
        cache.mintAmount = GlvDepositCalc.getMintAmount(
            params.dataStore,
            params.oracle,
            glvDeposit,
            cache.receivedMarketTokens,
            cache.glvValue,
            cache.glvSupply
        );
        if (cache.mintAmount < glvDeposit.minGlvTokens()) {
            revert Errors.MinGlvTokens(cache.mintAmount, glvDeposit.minGlvTokens());
        }

        GlvToken(payable(glvDeposit.glv())).mint(glvDeposit.receiver(), cache.mintAmount);

        cache.market = MarketUtils.getEnabledMarket(params.dataStore, glvDeposit.market());
        cache.marketPoolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            cache.market,
            params.oracle.getPrimaryPrice(cache.market.indexToken),
            params.oracle.getPrimaryPrice(cache.market.longToken),
            params.oracle.getPrimaryPrice(cache.market.shortToken),
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            true // maximize
        );
        cache.marketTokenSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(glvDeposit.market())));

        GlvUtils.validateGlvMarketTokenBalance(
            params.dataStore,
            glvDeposit.glv(),
            cache.market,
            cache.marketPoolValueInfo.poolValue.toUint256(),
            cache.marketTokenSupply
        );

        GlvDepositEventUtils.emitGlvDepositExecuted(
            params.eventEmitter,
            params.key,
            glvDeposit.account(),
            cache.mintAmount
        );

        cache.glvValue = GlvUtils.getGlvValue(
            params.dataStore,
            params.oracle,
            glvDeposit.glv(),
            true // maximize
        );
        cache.glvSupply = GlvToken(payable(glvDeposit.glv())).totalSupply();
        GlvEventUtils.emitGlvValueUpdated(params.eventEmitter, glvDeposit.glv(), cache.glvValue, cache.glvSupply);

        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "receivedGlvTokens", cache.mintAmount);
        CallbackUtils.afterGlvDepositExecution(params.key, glvDeposit, eventData);

        cache.marketCount = GlvUtils.getGlvMarketCount(params.dataStore, glvDeposit.glv());
        cache.oraclePriceCount = GasUtils.estimateGlvDepositOraclePriceCount(
            cache.marketCount,
            glvDeposit.longTokenSwapPath().length + glvDeposit.shortTokenSwapPath().length
        );
        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.glvVault,
            params.key,
            glvDeposit.callbackContract(),
            glvDeposit.executionFee(),
            params.startingGas,
            cache.oraclePriceCount,
            params.keeper,
            glvDeposit.receiver()
        );

        return cache.mintAmount;
    }


    function _processMarketDeposit(
        ExecuteGlvDepositParams memory params,
        GlvDeposit.Props memory glvDeposit,
        GlvVault glvVault
    ) private returns (uint256) {
        if (glvDeposit.isMarketTokenDeposit()) {
            Market.Props memory market = MarketUtils.getEnabledMarket(params.dataStore, glvDeposit.market());

            MarketUtils.MarketPrices memory marketPrices = MarketUtils.MarketPrices(
                params.oracle.getPrimaryPrice(market.indexToken),
                params.oracle.getPrimaryPrice(market.longToken),
                params.oracle.getPrimaryPrice(market.shortToken)
            );
            MarketUtils.validateMaxPnl(
                params.dataStore,
                market,
                marketPrices,
                Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
                Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS
            );

            // user deposited GM tokens
            glvVault.transferOut(glvDeposit.market(), glvDeposit.glv(), glvDeposit.marketTokenAmount());
            return glvDeposit.marketTokenAmount();
        }

        Deposit.Props memory deposit = Deposit.Props(
            Deposit.Addresses({
                account: glvDeposit.glv(),
                receiver: glvDeposit.glv(),
                callbackContract: address(0),
                uiFeeReceiver: glvDeposit.uiFeeReceiver(),
                market: glvDeposit.market(),
                initialLongToken: glvDeposit.initialLongToken(),
                initialShortToken: glvDeposit.initialShortToken(),
                longTokenSwapPath: glvDeposit.longTokenSwapPath(),
                shortTokenSwapPath: glvDeposit.shortTokenSwapPath()
            }),
            Deposit.Numbers({
                initialLongTokenAmount: glvDeposit.initialLongTokenAmount(),
                initialShortTokenAmount: glvDeposit.initialShortTokenAmount(),
                minMarketTokens: 0,
                updatedAtTime: glvDeposit.updatedAtTime(),
                executionFee: 0,
                callbackGasLimit: 0,
                chainId: 0
            }),
            Deposit.Flags({shouldUnwrapNativeToken: false}),
            new bytes32[](0) // dataList
        );

        bytes32 depositKey = NonceUtils.getNextKey(params.dataStore);
        params.dataStore.addBytes32(Keys.DEPOSIT_LIST, depositKey);
        DepositEventUtils.emitDepositCreated(params.eventEmitter, depositKey, deposit, Deposit.DepositType.Glv);

        ExecuteDepositUtils.ExecuteDepositParams memory executeDepositParams = ExecuteDepositUtils.ExecuteDepositParams(
                params.dataStore,
                params.eventEmitter,
                DepositVault(payable(params.glvVault)),
                params.oracle,
                depositKey,
                params.keeper,
                params.startingGas,
                ISwapPricingUtils.SwapPricingType.Deposit,
                true // includeVirtualInventoryImpact
            );

        uint256 receivedMarketTokens = ExecuteDepositUtils.executeDeposit(executeDepositParams, deposit);
        return receivedMarketTokens;
    }

    function cancelGlvDeposit(CancelGlvDepositParams memory params) external {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(params.dataStore, params.key);
        GlvDepositStoreUtils.remove(params.dataStore, params.key, glvDeposit.account());

        if (glvDeposit.isMarketTokenDeposit()) {
            // in this case marketTokenAmount > 0
            params.glvVault.transferOut(
                glvDeposit.market(),
                glvDeposit.account(),
                glvDeposit.marketTokenAmount(),
                glvDeposit.shouldUnwrapNativeToken()
            );
        } else {
            if (glvDeposit.initialLongTokenAmount() > 0) {
                params.glvVault.transferOut(
                    glvDeposit.initialLongToken(),
                    glvDeposit.account(),
                    glvDeposit.initialLongTokenAmount(),
                    glvDeposit.shouldUnwrapNativeToken()
                );
            }

            if (glvDeposit.initialShortTokenAmount() > 0) {
                params.glvVault.transferOut(
                    glvDeposit.initialShortToken(),
                    glvDeposit.account(),
                    glvDeposit.initialShortTokenAmount(),
                    glvDeposit.shouldUnwrapNativeToken()
                );
            }
        }

        GlvDepositEventUtils.emitGlvDepositCancelled(
            params.eventEmitter,
            params.key,
            glvDeposit.account(),
            params.reason,
            params.reasonBytes
        );

        EventUtils.EventLogData memory eventData;
        CallbackUtils.afterGlvDepositCancellation(params.key, glvDeposit, eventData);

        uint256 marketCount = GlvUtils.getGlvMarketCount(params.dataStore, glvDeposit.glv());
        uint256 oraclePriceCount = GasUtils.estimateGlvDepositOraclePriceCount(
            marketCount,
            glvDeposit.longTokenSwapPath().length + glvDeposit.shortTokenSwapPath().length
        );
        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.glvVault,
            params.key,
            glvDeposit.callbackContract(),
            glvDeposit.executionFee(),
            params.startingGas,
            oraclePriceCount,
            params.keeper,
            glvDeposit.receiver()
        );
    }
}
