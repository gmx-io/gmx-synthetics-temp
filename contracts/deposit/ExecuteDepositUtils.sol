// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "./DepositVault.sol";
import "./DepositStoreUtils.sol";
import "./DepositEventUtils.sol";

import "../pricing/SwapPricingUtils.sol";
import "../oracle/Oracle.sol";
import "../position/PositionUtils.sol";

import "../gas/GasUtils.sol";
import "../callback/CallbackUtils.sol";

import "../utils/Array.sol";

// @title DepositUtils
// @dev Library for deposit functions, to help with the depositing of liquidity
// into a market in return for market tokens
library ExecuteDepositUtils {
    using SafeCast for uint256;
    using SafeCast for int256;
    using Array for uint256[];

    using Price for Price.Props;
    using Deposit for Deposit.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    // @dev ExecuteDepositParams struct used in executeDeposit to avoid stack
    // too deep errors
    struct ExecuteDepositParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        DepositVault depositVault;
        Oracle oracle;
        bytes32 key;
        address keeper;
        uint256 startingGas;
        ISwapPricingUtils.SwapPricingType swapPricingType;
        bool includeVirtualInventoryImpact;
    }

    // @dev _ExecuteDepositParams struct used in executeDeposit to avoid stack
    // too deep errors
    //
    // @param market the market to deposit into
    // @param account the depositing account
    // @param receiver the account to send the market tokens to
    // @param uiFeeReceiver the ui fee receiver account
    // @param tokenIn the token to deposit, either the market.longToken or
    // market.shortToken
    // @param tokenOut the other token, if tokenIn is market.longToken then
    // tokenOut is market.shortToken and vice versa
    // @param tokenInPrice price of tokenIn
    // @param tokenOutPrice price of tokenOut
    // @param amount amount of tokenIn
    // @param priceImpactUsd price impact in USD
    struct _ExecuteDepositParams {
        Market.Props market;
        address account;
        address receiver;
        address uiFeeReceiver;
        address tokenIn;
        address tokenOut;
        Price.Props tokenInPrice;
        Price.Props tokenOutPrice;
        uint256 amount;
        int256 priceImpactUsd;
    }

    struct ExecuteDepositCache {
        uint256 requestExpirationTime;
        uint256 maxOracleTimestamp;
        Market.Props market;
        MarketUtils.MarketPrices prices;
        uint256 longTokenAmount;
        uint256 shortTokenAmount;
        uint256 longTokenUsd;
        uint256 shortTokenUsd;
        uint256 receivedMarketTokens;
        int256 priceImpactUsd;
        bool balanceWasImproved;
        uint256 marketTokensSupply;
        EventUtils.EventLogData callbackEventData;
    }

    address public constant RECEIVER_FOR_FIRST_DEPOSIT = address(1);

    // @dev executes a deposit
    // @param params ExecuteDepositParams
    function executeDeposit(ExecuteDepositParams memory params, Deposit.Props memory deposit) external returns (uint256 receivedMarketTokens) {
        // 63/64 gas is forwarded to external calls, reduce the startingGas to account for this
        params.startingGas -= gasleft() / 63;

        DepositStoreUtils.remove(params.dataStore, params.key, deposit.account());


        if (deposit.account() == address(0)) {
            revert Errors.EmptyDeposit();
        }

        if (params.oracle.minTimestamp() < deposit.updatedAtTime()) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(
                params.oracle.minTimestamp(),
                deposit.updatedAtTime()
            );
        }

        ExecuteDepositCache memory cache;
        cache.requestExpirationTime = params.dataStore.getUint(Keys.REQUEST_EXPIRATION_TIME);
        cache.maxOracleTimestamp = params.oracle.maxTimestamp();

        if (cache.maxOracleTimestamp > deposit.updatedAtTime() + cache.requestExpirationTime) {
            revert Errors.OracleTimestampsAreLargerThanRequestExpirationTime(
                cache.maxOracleTimestamp,
                deposit.updatedAtTime(),
                cache.requestExpirationTime
            );
        }

        cache.market = MarketUtils.getEnabledMarket(params.dataStore, deposit.market());

        _validateFirstDeposit(params, deposit, cache.market);

        cache.prices = MarketUtils.getMarketPrices(params.oracle, cache.market);

        MarketUtils.distributePositionImpactPool(
            params.dataStore,
            params.eventEmitter,
            cache.market.marketToken
        );

        PositionUtils.updateFundingAndBorrowingState(
            params.dataStore,
            params.eventEmitter,
            cache.market,
            cache.prices
        );

        // deposits should improve the pool state but it should be checked if
        // the max pnl factor for deposits is exceeded as this would lead to the
        // price of the market token decreasing below a target minimum percentage
        // due to pnl
        // note that this is just a validation for deposits, there is no actual
        // minimum price for a market token
        MarketUtils.validateMaxPnl(
            params.dataStore,
            cache.market,
            cache.prices,
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS
        );

        cache.longTokenAmount = swap(
            params,
            deposit.longTokenSwapPath(),
            deposit.initialLongToken(),
            deposit.initialLongTokenAmount(),
            cache.market.marketToken,
            cache.market.longToken,
            deposit.uiFeeReceiver()
        );

        cache.shortTokenAmount = swap(
            params,
            deposit.shortTokenSwapPath(),
            deposit.initialShortToken(),
            deposit.initialShortTokenAmount(),
            cache.market.marketToken,
            cache.market.shortToken,
            deposit.uiFeeReceiver()
        );

        if (cache.longTokenAmount == 0 && cache.shortTokenAmount == 0) {
            revert Errors.EmptyDepositAmountsAfterSwap();
        }

        cache.longTokenUsd = cache.longTokenAmount * cache.prices.longTokenPrice.midPrice();
        cache.shortTokenUsd = cache.shortTokenAmount * cache.prices.shortTokenPrice.midPrice();

        (cache.priceImpactUsd, cache.balanceWasImproved) = SwapPricingUtils.getPriceImpactUsd(
            SwapPricingUtils.GetPriceImpactUsdParams(
                params.dataStore,
                cache.market,
                cache.market.longToken,
                cache.market.shortToken,
                cache.prices.longTokenPrice.midPrice(),
                cache.prices.shortTokenPrice.midPrice(),
                cache.longTokenUsd.toInt256(),
                cache.shortTokenUsd.toInt256(),
                params.includeVirtualInventoryImpact
            )
        );

        if (cache.longTokenAmount > 0) {
            _ExecuteDepositParams memory _params = _ExecuteDepositParams(
                cache.market,
                deposit.account(),
                deposit.receiver(),
                deposit.uiFeeReceiver(),
                cache.market.longToken,
                cache.market.shortToken,
                cache.prices.longTokenPrice,
                cache.prices.shortTokenPrice,
                cache.longTokenAmount,
                Precision.mulDiv(cache.priceImpactUsd, cache.longTokenUsd, cache.longTokenUsd + cache.shortTokenUsd)
            );

            cache.receivedMarketTokens += _executeDeposit(params, _params, cache.balanceWasImproved);
        }

        if (cache.shortTokenAmount > 0) {
            _ExecuteDepositParams memory _params = _ExecuteDepositParams(
                cache.market,
                deposit.account(),
                deposit.receiver(),
                deposit.uiFeeReceiver(),
                cache.market.shortToken,
                cache.market.longToken,
                cache.prices.shortTokenPrice,
                cache.prices.longTokenPrice,
                cache.shortTokenAmount,
                Precision.mulDiv(cache.priceImpactUsd, cache.shortTokenUsd, cache.longTokenUsd + cache.shortTokenUsd)
            );

            cache.receivedMarketTokens += _executeDeposit(params, _params, cache.balanceWasImproved);
        }

        if (cache.receivedMarketTokens < deposit.minMarketTokens()) {
            revert Errors.MinMarketTokens(cache.receivedMarketTokens, deposit.minMarketTokens());
        }

        // validate that internal state changes are correct before calling
        // external callbacks
        MarketUtils.validateMarketTokenBalance(params.dataStore, cache.market);

        DepositEventUtils.emitDepositExecuted(
            params.eventEmitter,
            params.key,
            deposit.account(),
            cache.longTokenAmount,
            cache.shortTokenAmount,
            cache.receivedMarketTokens,
            params.swapPricingType
        );

        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            cache.market,
            cache.prices.indexTokenPrice,
            cache.prices.longTokenPrice,
            cache.prices.shortTokenPrice,
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            true
        );

        cache.marketTokensSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(cache.market.marketToken)));

        MarketEventUtils.emitMarketPoolValueUpdated(
            params.eventEmitter,
            keccak256(abi.encode("DEPOSIT")),
            params.key,
            cache.market.marketToken,
            poolValueInfo,
            cache.marketTokensSupply
        );

        cache.callbackEventData.uintItems.initItems(1);
        cache.callbackEventData.uintItems.setItem(0, "receivedMarketTokens", cache.receivedMarketTokens);
        CallbackUtils.afterDepositExecution(params.key, deposit, cache.callbackEventData);

        GasUtils.payExecutionFee(
            params.dataStore,
            params.eventEmitter,
            params.depositVault,
            params.key,
            deposit.callbackContract(),
            deposit.executionFee(),
            params.startingGas,
            GasUtils.estimateDepositOraclePriceCount(deposit.longTokenSwapPath().length + deposit.shortTokenSwapPath().length),
            params.keeper,
            deposit.receiver()
        );

        return cache.receivedMarketTokens;
    }

    // @dev executes a deposit
    // @param params ExecuteDepositParams
    // @param _params _ExecuteDepositParams
    function _executeDeposit(ExecuteDepositParams memory params, _ExecuteDepositParams memory _params, bool balanceWasImproved) internal returns (uint256) {
        // for markets where longToken == shortToken, the price impact factor should be set to zero
        // in which case, the priceImpactUsd would always equal zero
        SwapPricingUtils.SwapFees memory fees = SwapPricingUtils.getSwapFees(
            params.dataStore,
            _params.market.marketToken,
            _params.amount,
            balanceWasImproved,
            _params.uiFeeReceiver,
            params.swapPricingType
        );

        FeeUtils.incrementClaimableFeeAmount(
            params.dataStore,
            params.eventEmitter,
            _params.market.marketToken,
            _params.tokenIn,
            fees.feeReceiverAmount,
            Keys.DEPOSIT_FEE_TYPE
        );

        FeeUtils.incrementClaimableUiFeeAmount(
            params.dataStore,
            params.eventEmitter,
            _params.uiFeeReceiver,
            _params.market.marketToken,
            _params.tokenIn,
            fees.uiFeeAmount,
            Keys.UI_DEPOSIT_FEE_TYPE
        );

        SwapPricingUtils.emitSwapFeesCollected(
            params.eventEmitter,
            params.key,
            _params.market.marketToken,
            _params.tokenIn,
            _params.tokenInPrice.min,
            Keys.DEPOSIT_FEE_TYPE,
            fees
         );

        uint256 mintAmount;

        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            params.dataStore,
            _params.market,
            params.oracle.getPrimaryPrice(_params.market.indexToken),
            _params.tokenIn == _params.market.longToken ? _params.tokenInPrice : _params.tokenOutPrice,
            _params.tokenIn == _params.market.shortToken ? _params.tokenInPrice : _params.tokenOutPrice,
            Keys.MAX_PNL_FACTOR_FOR_DEPOSITS,
            true
        );

        if (poolValueInfo.poolValue < 0) {
            revert Errors.InvalidPoolValueForDeposit(poolValueInfo.poolValue);
        }

        uint256 poolValue = poolValueInfo.poolValue.toUint256();

        uint256 marketTokensSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(_params.market.marketToken)));

        if (poolValueInfo.poolValue == 0 && marketTokensSupply > 0) {
            revert Errors.InvalidPoolValueForDeposit(poolValueInfo.poolValue);
        }

        MarketEventUtils.emitMarketPoolValueInfo(
            params.eventEmitter,
            params.key,
            _params.market.marketToken,
            poolValueInfo,
            marketTokensSupply
        );

        // the poolValue and marketTokensSupply is cached for the mintAmount calculation below
        // so the effect of any positive price impact on the poolValue and marketTokensSupply
        // would not be accounted for
        //
        // for most cases, this should not be an issue, since the poolValue and marketTokensSupply
        // should have been proportionately increased
        //
        // e.g. if the poolValue is $100 and marketTokensSupply is 100, and there is a positive price impact
        // of $10, the poolValue should have increased by $10 and the marketTokensSupply should have been increased by 10
        //
        // there is a case where this may be an issue which is when all tokens are withdrawn from an existing market
        // and the marketTokensSupply is reset to zero, but the poolValue is not entirely zero
        // the case where this happens should be very rare and during withdrawal the poolValue should be close to zero
        //
        // however, in case this occurs, the usdToMarketTokenAmount will mint an additional number of market tokens
        // proportional to the existing poolValue
        //
        // since the poolValue and marketTokensSupply is cached, this could occur once during positive price impact
        // and again when calculating the mintAmount
        //
        // to avoid this, set the priceImpactUsd to be zero for this case
        if (_params.priceImpactUsd > 0 && marketTokensSupply == 0) {
            _params.priceImpactUsd = 0;
        }

        if (_params.priceImpactUsd > 0) {
            // when there is a positive price impact factor,
            // tokens from the swap impact pool are used to mint additional market tokens for the user
            // for example, if 50,000 USDC is deposited and there is a positive price impact
            // an additional 0.005 ETH may be used to mint market tokens
            // the swap impact pool is decreased by the used amount
            //
            // priceImpactUsd is calculated based on pricing assuming only depositAmount of tokenIn
            // was added to the pool
            // since impactAmount of tokenOut is added to the pool here, the calculation of
            // the price impact would not be entirely accurate
            //
            // it is possible that the addition of the positive impact amount of tokens into the pool
            // could increase the imbalance of the pool, for most cases this should not be a significant
            // change compared to the improvement of balance from the actual deposit
            (int256 positiveImpactAmount, /* uint256 cappedDiffUsd */) = MarketUtils.applySwapImpactWithCap(
                params.dataStore,
                params.eventEmitter,
                _params.market.marketToken,
                _params.tokenOut,
                _params.tokenOutPrice,
                _params.priceImpactUsd
            );

            // calculate the usd amount using positiveImpactAmount since it may
            // be capped by the max available amount in the impact pool
            // use tokenOutPrice.max to get the USD value since the positiveImpactAmount
            // was calculated using a USD value divided by tokenOutPrice.max
            //
            // for the initial deposit, the pool value and token supply would be zero
            // so the market token price is treated as 1 USD
            //
            // it is possible for the pool value to be more than zero and the token supply
            // to be zero, in that case, the market token price is also treated as 1 USD
            mintAmount += MarketUtils.usdToMarketTokenAmount(
                positiveImpactAmount.toUint256() * _params.tokenOutPrice.max,
                poolValue,
                marketTokensSupply
            );

            // deposit the token out, that was withdrawn from the impact pool, to mint market tokens
            MarketUtils.applyDeltaToPoolAmount(
                params.dataStore,
                params.eventEmitter,
                _params.market,
                _params.tokenOut,
                positiveImpactAmount
            );

            // MarketUtils.validatePoolUsdForDeposit is not called here
            // this is to prevent unnecessary reverts
            // for example, if the pool's long token is close to the deposit cap
            // but the short token is not close to the cap, depositing the short
            // token can lead to a positive price impact which can cause the
            // long token's deposit cap to be exceeded
            // in this case, it is preferrable that the pool can still be
            // rebalanced even if the deposit cap may be exceeded

            MarketUtils.validatePoolAmount(
                params.dataStore,
                _params.market,
                _params.tokenOut
            );
        }

        if (_params.priceImpactUsd < 0) {
            // when there is a negative price impact factor,
            // less of the deposit amount is used to mint market tokens
            // for example, if 10 ETH is deposited and there is a negative price impact
            // only 9.995 ETH may be used to mint market tokens
            // the remaining 0.005 ETH will be stored in the swap impact pool
            (int256 negativeImpactAmount, /* uint256 cappedDiffUsd */) = MarketUtils.applySwapImpactWithCap(
                params.dataStore,
                params.eventEmitter,
                _params.market.marketToken,
                _params.tokenIn,
                _params.tokenInPrice,
                _params.priceImpactUsd
            );

            fees.amountAfterFees -= (-negativeImpactAmount).toUint256();
        }

        mintAmount += MarketUtils.usdToMarketTokenAmount(
            fees.amountAfterFees * _params.tokenInPrice.min,
            poolValue,
            marketTokensSupply
        );

        MarketUtils.applyDeltaToPoolAmount(
            params.dataStore,
            params.eventEmitter,
            _params.market,
            _params.tokenIn,
            (fees.amountAfterFees + fees.feeAmountForPool).toInt256()
        );

        MarketUtils.validatePoolUsdForDeposit(
            params.dataStore,
            _params.market,
            _params.tokenIn,
            _params.tokenInPrice.max
        );

        MarketUtils.validatePoolAmount(
            params.dataStore,
            _params.market,
            _params.tokenIn
        );

        MarketToken(payable(_params.market.marketToken)).mint(_params.receiver, mintAmount);

        return mintAmount;
    }

    function swap(
        ExecuteDepositParams memory params,
        address[] memory swapPath,
        address initialToken,
        uint256 inputAmount,
        address market,
        address expectedOutputToken,
        address uiFeeReceiver
    ) internal returns (uint256) {
        Market.Props[] memory swapPathMarkets = MarketUtils.getSwapPathMarkets(
            params.dataStore,
            swapPath
        );

        (address outputToken, uint256 outputAmount) = SwapUtils.swap(
            SwapUtils.SwapParams(
                params.dataStore, // dataStore
                params.eventEmitter, // eventEmitter
                params.oracle, // oracle
                params.depositVault, // bank
                params.key, // key
                initialToken, // tokenIn
                inputAmount, // amountIn
                swapPathMarkets, // swapPathMarkets
                0, // minOutputAmount
                market, // receiver
                uiFeeReceiver, // uiFeeReceiver
                false // shouldUnwrapNativeToken
            )
        );

        if (outputToken != expectedOutputToken) {
            revert Errors.InvalidSwapOutputToken(outputToken, expectedOutputToken);
        }

        MarketUtils.validateMarketTokenBalance(params.dataStore, swapPathMarkets);

        return outputAmount;
    }

    // this method validates that a specified minimum number of market tokens are locked
    // this can be used to help ensure a minimum amount of liquidity for a market
    // this also helps to prevent manipulation of the market token price by the first depositor
    // since it may be possible to deposit a small amount of tokens on the first deposit
    // to cause a high market token price due to rounding of the amount of tokens minted
    function _validateFirstDeposit(
        ExecuteDepositParams memory params,
        Deposit.Props memory deposit,
        Market.Props memory market
    ) internal view {
        uint256 initialMarketTokensSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(market.marketToken)));

        // return if this is not the first deposit
        if (initialMarketTokensSupply != 0) { return; }

        uint256 minMarketTokens = params.dataStore.getUint(Keys.minMarketTokensForFirstDepositKey(market.marketToken));

        // return if there is no minMarketTokens requirement
        if (minMarketTokens == 0) { return; }

        if (deposit.receiver() != RECEIVER_FOR_FIRST_DEPOSIT) {
            revert Errors.InvalidReceiverForFirstDeposit(deposit.receiver(), RECEIVER_FOR_FIRST_DEPOSIT);
        }

        if (deposit.minMarketTokens() < minMarketTokens) {
            revert Errors.InvalidMinMarketTokensForFirstDeposit(deposit.minMarketTokens(), minMarketTokens);
        }
    }
}
