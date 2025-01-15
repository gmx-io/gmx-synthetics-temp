// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";

import "./WithdrawalVault.sol";
import "./WithdrawalStoreUtils.sol";
import "./WithdrawalEventUtils.sol";

import "../pricing/SwapPricingUtils.sol";
import "../oracle/Oracle.sol";
import "../position/PositionUtils.sol";

import "../gas/GasUtils.sol";
import "../callback/CallbackUtils.sol";

import "../utils/Array.sol";

library ExecuteWithdrawalUtils {
    using SafeCast for uint256;
    using SafeCast for int256;
    using Array for uint256[];
    using Price for Price.Props;
    using Withdrawal for Withdrawal.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    struct ExecuteWithdrawalParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        WithdrawalVault withdrawalVault;
        Oracle oracle;
        bytes32 key;
        address keeper;
        uint256 startingGas;
        ISwapPricingUtils.SwapPricingType swapPricingType;
    }

    struct ExecuteWithdrawalCache {
        uint256 requestExpirationTime;
        uint256 maxOracleTimestamp;
        uint256 marketTokensBalance;
        uint256 oraclePriceCount;
        Market.Props market;
        MarketUtils.MarketPrices prices;
        ExecuteWithdrawalResult result;
    }

    struct _ExecuteWithdrawalCache {
        uint256 longTokenOutputAmount;
        uint256 shortTokenOutputAmount;
        SwapPricingUtils.SwapFees longTokenFees;
        SwapPricingUtils.SwapFees shortTokenFees;
        uint256 longTokenPoolAmountDelta;
        uint256 shortTokenPoolAmountDelta;
    }

    struct ExecuteWithdrawalResult {
        address outputToken;
        uint256 outputAmount;
        address secondaryOutputToken;
        uint256 secondaryOutputAmount;
    }

    struct SwapCache {
        Market.Props[] swapPathMarkets;
        SwapUtils.SwapParams swapParams;
        address outputToken;
        uint256 outputAmount;
    }

    /**
     * Executes a withdrawal on the market.
     *
     * @param params The parameters for executing the withdrawal.
     */
    function executeWithdrawal(
        ExecuteWithdrawalParams memory params,
        Withdrawal.Props memory withdrawal
    ) external returns (ExecuteWithdrawalResult memory) {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        WithdrawalStoreUtils.remove(params.dataStore, params.key, withdrawal.account());

        if (withdrawal.account() == address(0)) {
            revert Errors.EmptyWithdrawal();
        }
        if (withdrawal.marketTokenAmount() == 0) {
            revert Errors.EmptyWithdrawalAmount();
        }

        if (params.oracle.minTimestamp() < withdrawal.updatedAtTime()) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(
                params.oracle.minTimestamp(),
                withdrawal.updatedAtTime()
            );
        }

        ExecuteWithdrawalCache memory cache;

        cache.requestExpirationTime = params.dataStore.getUint(Keys.REQUEST_EXPIRATION_TIME);
        cache.maxOracleTimestamp = params.oracle.maxTimestamp();

        if (cache.maxOracleTimestamp > withdrawal.updatedAtTime() + cache.requestExpirationTime) {
            revert Errors.OracleTimestampsAreLargerThanRequestExpirationTime(
                cache.maxOracleTimestamp,
                withdrawal.updatedAtTime(),
                cache.requestExpirationTime
            );
        }

        MarketUtils.distributePositionImpactPool(params.dataStore, params.eventEmitter, withdrawal.market());

        cache.market = MarketUtils.getEnabledMarket(params.dataStore, withdrawal.market());
        cache.prices = MarketUtils.getMarketPrices(params.oracle, cache.market);

        PositionUtils.updateFundingAndBorrowingState(params.dataStore, params.eventEmitter, cache.market, cache.prices);

        cache.marketTokensBalance = MarketToken(payable(withdrawal.market())).balanceOf(
            address(params.withdrawalVault)
        );
        if (cache.marketTokensBalance < withdrawal.marketTokenAmount()) {
            revert Errors.InsufficientMarketTokens(cache.marketTokensBalance, withdrawal.marketTokenAmount());
        }

        cache.result = _executeWithdrawal(params, withdrawal, cache.market, cache.prices);

        WithdrawalEventUtils.emitWithdrawalExecuted(
            params.eventEmitter,
            params.key,
            withdrawal.account(),
            params.swapPricingType
        );

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "outputToken", cache.result.outputToken);
        eventData.addressItems.setItem(1, "secondaryOutputToken", cache.result.secondaryOutputToken);
        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "outputAmount", cache.result.outputAmount);
        eventData.uintItems.setItem(1, "secondaryOutputAmount", cache.result.secondaryOutputAmount);
        CallbackUtils.afterWithdrawalExecution(params.key, withdrawal, eventData);

        cache.oraclePriceCount = GasUtils.estimateWithdrawalOraclePriceCount(
            withdrawal.longTokenSwapPath().length + withdrawal.shortTokenSwapPath().length
        );

        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.withdrawalVault,
            params.key,
            withdrawal.callbackContract(),
            withdrawal.executionFee(),
            params.startingGas,
            cache.oraclePriceCount,
            params.keeper,
            withdrawal.receiver()
        );

        return cache.result;
    }

    /**
     * @dev executes a withdrawal.
     * @param params ExecuteWithdrawalParams.
     * @param withdrawal The withdrawal to execute.
     */
    function _executeWithdrawal(
        ExecuteWithdrawalParams memory params,
        Withdrawal.Props memory withdrawal,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices
    ) internal returns (ExecuteWithdrawalResult memory) {
        _ExecuteWithdrawalCache memory cache;

        (cache.longTokenOutputAmount, cache.shortTokenOutputAmount) = _getOutputAmounts(
            params,
            market,
            prices,
            withdrawal.marketTokenAmount()
        );

        cache.longTokenFees = SwapPricingUtils.getSwapFees(
            params.dataStore,
            market.marketToken,
            cache.longTokenOutputAmount,
            false, // balanceWasImproved
            withdrawal.uiFeeReceiver(),
            params.swapPricingType
        );

        FeeUtils.incrementClaimableFeeAmount(
            params.dataStore,
            params.eventEmitter,
            market.marketToken,
            market.longToken,
            cache.longTokenFees.feeReceiverAmount,
            Keys.WITHDRAWAL_FEE_TYPE
        );

        FeeUtils.incrementClaimableUiFeeAmount(
            params.dataStore,
            params.eventEmitter,
            withdrawal.uiFeeReceiver(),
            market.marketToken,
            market.longToken,
            cache.longTokenFees.uiFeeAmount,
            Keys.UI_WITHDRAWAL_FEE_TYPE
        );

        cache.shortTokenFees = SwapPricingUtils.getSwapFees(
            params.dataStore,
            market.marketToken,
            cache.shortTokenOutputAmount,
            false, // balanceWasImproved
            withdrawal.uiFeeReceiver(),
            params.swapPricingType
        );

        FeeUtils.incrementClaimableFeeAmount(
            params.dataStore,
            params.eventEmitter,
            market.marketToken,
            market.shortToken,
            cache.shortTokenFees.feeReceiverAmount,
            Keys.WITHDRAWAL_FEE_TYPE
        );

        FeeUtils.incrementClaimableUiFeeAmount(
            params.dataStore,
            params.eventEmitter,
            withdrawal.uiFeeReceiver(),
            market.marketToken,
            market.shortToken,
            cache.shortTokenFees.uiFeeAmount,
            Keys.UI_WITHDRAWAL_FEE_TYPE
        );

        // the pool will be reduced by the outputAmount minus the fees for the pool
        cache.longTokenPoolAmountDelta = cache.longTokenOutputAmount - cache.longTokenFees.feeAmountForPool;
        cache.longTokenOutputAmount = cache.longTokenFees.amountAfterFees;

        cache.shortTokenPoolAmountDelta = cache.shortTokenOutputAmount - cache.shortTokenFees.feeAmountForPool;
        cache.shortTokenOutputAmount = cache.shortTokenFees.amountAfterFees;

        // it is rare but possible for withdrawals to be blocked because pending borrowing fees
        // have not yet been deducted from position collateral and credited to the poolAmount value
        MarketUtils.applyDeltaToPoolAmount(
            params.dataStore,
            params.eventEmitter,
            market,
            market.longToken,
            -cache.longTokenPoolAmountDelta.toInt256()
        );

        MarketUtils.applyDeltaToPoolAmount(
            params.dataStore,
            params.eventEmitter,
            market,
            market.shortToken,
            -cache.shortTokenPoolAmountDelta.toInt256()
        );

        MarketUtils.validateReserve(params.dataStore, market, prices, true);

        MarketUtils.validateReserve(params.dataStore, market, prices, false);

        MarketUtils.validateMaxPnl(
            params.dataStore,
            market,
            prices,
            Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
            Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS
        );

        MarketToken(payable(market.marketToken)).burn(address(params.withdrawalVault), withdrawal.marketTokenAmount());

        params.withdrawalVault.syncTokenBalance(market.marketToken);

        ExecuteWithdrawalResult memory result;
        (result.outputToken, result.outputAmount) = _swap(
            params,
            market,
            market.longToken,
            cache.longTokenOutputAmount,
            withdrawal.longTokenSwapPath(),
            withdrawal.minLongTokenAmount(),
            withdrawal.receiver(),
            withdrawal.uiFeeReceiver(),
            withdrawal.shouldUnwrapNativeToken()
        );

        (result.secondaryOutputToken, result.secondaryOutputAmount) = _swap(
            params,
            market,
            market.shortToken,
            cache.shortTokenOutputAmount,
            withdrawal.shortTokenSwapPath(),
            withdrawal.minShortTokenAmount(),
            withdrawal.receiver(),
            withdrawal.uiFeeReceiver(),
            withdrawal.shouldUnwrapNativeToken()
        );

        SwapPricingUtils.emitSwapFeesCollected(
            params.eventEmitter,
            params.key,
            market.marketToken,
            market.longToken,
            prices.longTokenPrice.min,
            Keys.WITHDRAWAL_FEE_TYPE,
            cache.longTokenFees
        );

        SwapPricingUtils.emitSwapFeesCollected(
            params.eventEmitter,
            params.key,
            market.marketToken,
            market.shortToken,
            prices.shortTokenPrice.min,
            Keys.WITHDRAWAL_FEE_TYPE,
            cache.shortTokenFees
        );

        // if the native token was transferred to the receiver in a swap
        // it may be possible to invoke external contracts before the validations
        // are called
        MarketUtils.validateMarketTokenBalance(params.dataStore, market);

        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            market,
            prices.indexTokenPrice,
            prices.longTokenPrice,
            prices.shortTokenPrice,
            Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
            false
        );

        uint256 marketTokensSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(market.marketToken)));

        MarketEventUtils.emitMarketPoolValueUpdated(
            params.eventEmitter,
            keccak256(abi.encode("WITHDRAWAL")),
            params.key,
            market.marketToken,
            poolValueInfo,
            marketTokensSupply
        );

        return result;
    }

    function _swap(
        ExecuteWithdrawalParams memory params,
        Market.Props memory market,
        address tokenIn,
        uint256 amountIn,
        address[] memory swapPath,
        uint256 minOutputAmount,
        address receiver,
        address uiFeeReceiver,
        bool shouldUnwrapNativeToken
    ) internal returns (address, uint256) {
        SwapCache memory cache;

        cache.swapPathMarkets = MarketUtils.getSwapPathMarkets(params.dataStore, swapPath);

        cache.swapParams.dataStore = params.dataStore;
        cache.swapParams.eventEmitter = params.eventEmitter;
        cache.swapParams.oracle = params.oracle;
        cache.swapParams.bank = Bank(payable(market.marketToken));
        cache.swapParams.key = params.key;
        cache.swapParams.tokenIn = tokenIn;
        cache.swapParams.amountIn = amountIn;
        cache.swapParams.swapPathMarkets = cache.swapPathMarkets;
        cache.swapParams.minOutputAmount = minOutputAmount;
        cache.swapParams.receiver = receiver;
        cache.swapParams.uiFeeReceiver = uiFeeReceiver;
        cache.swapParams.shouldUnwrapNativeToken = shouldUnwrapNativeToken;

        (cache.outputToken, cache.outputAmount) = SwapUtils.swap(cache.swapParams);

        // validate that internal state changes are correct before calling
        // external callbacks
        MarketUtils.validateMarketTokenBalance(params.dataStore, cache.swapPathMarkets);

        return (cache.outputToken, cache.outputAmount);
    }

    function _getOutputAmounts(
        ExecuteWithdrawalParams memory params,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        uint256 marketTokenAmount
    ) internal returns (uint256, uint256) {
        // the max pnl factor for withdrawals should be the lower of the max pnl factor values
        // which means that pnl would be capped to a smaller amount and the pool
        // value would be higher even if there is a large pnl
        // this should be okay since MarketUtils.validateMaxPnl is called after the withdrawal
        // which ensures that the max pnl factor for withdrawals was not exceeded
        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            market,
            params.oracle.getPrimaryPrice(market.indexToken),
            prices.longTokenPrice,
            prices.shortTokenPrice,
            Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
            false
        );

        if (poolValueInfo.poolValue <= 0) {
            revert Errors.InvalidPoolValueForWithdrawal(poolValueInfo.poolValue);
        }

        uint256 poolValue = poolValueInfo.poolValue.toUint256();
        uint256 marketTokensSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(market.marketToken)));

        MarketEventUtils.emitMarketPoolValueInfo(
            params.eventEmitter,
            params.key,
            market.marketToken,
            poolValueInfo,
            marketTokensSupply
        );

        uint256 longTokenPoolAmount = MarketUtils.getPoolAmount(params.dataStore, market, market.longToken);
        uint256 shortTokenPoolAmount = MarketUtils.getPoolAmount(params.dataStore, market, market.shortToken);

        uint256 longTokenPoolUsd = longTokenPoolAmount * prices.longTokenPrice.max;
        uint256 shortTokenPoolUsd = shortTokenPoolAmount * prices.shortTokenPrice.max;

        uint256 totalPoolUsd = longTokenPoolUsd + shortTokenPoolUsd;

        uint256 marketTokensUsd = MarketUtils.marketTokenAmountToUsd(marketTokenAmount, poolValue, marketTokensSupply);

        uint256 longTokenOutputUsd = Precision.mulDiv(marketTokensUsd, longTokenPoolUsd, totalPoolUsd);
        uint256 shortTokenOutputUsd = Precision.mulDiv(marketTokensUsd, shortTokenPoolUsd, totalPoolUsd);

        return (longTokenOutputUsd / prices.longTokenPrice.max, shortTokenOutputUsd / prices.shortTokenPrice.max);
    }
}
