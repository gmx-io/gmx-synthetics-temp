// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "./Market.sol";
import "./MarketPoolValueInfo.sol";
import "./MarketToken.sol";
import "./MarketEventUtils.sol";
import "./MarketStoreUtils.sol";

import "../position/Position.sol";
import "../order/Order.sol";

import "../oracle/Oracle.sol";
import "../price/Price.sol";

import "../utils/Calc.sol";
import "../utils/Precision.sol";

import "../feature/FeatureUtils.sol";

// @title MarketUtils
// @dev Library for market functions
library MarketUtils {
    using SignedMath for int256;
    using SafeCast for int256;
    using SafeCast for uint256;

    using Market for Market.Props;
    using Position for Position.Props;
    using Order for Order.Props;
    using Price for Price.Props;

    enum FundingRateChangeType {
        NoChange,
        Increase,
        Decrease
    }

    // @dev struct to store the prices of tokens of a market
    // @param indexTokenPrice price of the market's index token
    // @param longTokenPrice price of the market's long token
    // @param shortTokenPrice price of the market's short token
    struct MarketPrices {
        Price.Props indexTokenPrice;
        Price.Props longTokenPrice;
        Price.Props shortTokenPrice;
    }

    struct CollateralType {
        uint256 longToken;
        uint256 shortToken;
    }

    struct PositionType {
        CollateralType long;
        CollateralType short;
    }

    // @dev struct for the result of the getNextFundingAmountPerSize call
    // note that abs(nextSavedFundingFactorPerSecond) may not equal the fundingFactorPerSecond
    // see getNextFundingFactorPerSecond for more info
    struct GetNextFundingAmountPerSizeResult {
        bool longsPayShorts;
        uint256 fundingFactorPerSecond;
        int256 nextSavedFundingFactorPerSecond;

        PositionType fundingFeeAmountPerSizeDelta;
        PositionType claimableFundingAmountPerSizeDelta;
    }

    struct GetNextFundingAmountPerSizeCache {
        PositionType openInterest;

        uint256 longOpenInterest;
        uint256 shortOpenInterest;

        uint256 durationInSeconds;

        uint256 sizeOfPayingSide;
        uint256 fundingUsd;

        uint256 fundingUsdForLongCollateral;
        uint256 fundingUsdForShortCollateral;
    }

    struct GetNextFundingFactorPerSecondCache {
        uint256 diffUsd;
        uint256 totalOpenInterest;

        uint256 fundingFactor;
        uint256 fundingExponentFactor;

        uint256 diffUsdAfterExponent;
        uint256 diffUsdToOpenInterestFactor;

        int256 savedFundingFactorPerSecond;
        uint256 savedFundingFactorPerSecondMagnitude;

        int256 nextSavedFundingFactorPerSecond;
        int256 nextSavedFundingFactorPerSecondWithMinBound;
    }

    struct FundingConfigCache {
        uint256 thresholdForStableFunding;
        uint256 thresholdForDecreaseFunding;

        uint256 fundingIncreaseFactorPerSecond;
        uint256 fundingDecreaseFactorPerSecond;

        uint256 minFundingFactorPerSecond;
        uint256 maxFundingFactorPerSecond;
    }

    struct GetExpectedMinTokenBalanceCache {
        uint256 poolAmount;
        uint256 swapImpactPoolAmount;
        uint256 claimableCollateralAmount;
        uint256 claimableFeeAmount;
        uint256 claimableUiFeeAmount;
        uint256 affiliateRewardAmount;
    }

    // @dev get the market token's price
    // @param dataStore DataStore
    // @param market the market to check
    // @param longTokenPrice the price of the long token
    // @param shortTokenPrice the price of the short token
    // @param indexTokenPrice the price of the index token
    // @param maximize whether to maximize or minimize the market token price
    // @return returns (the market token's price, MarketPoolValueInfo.Props)
    function getMarketTokenPrice(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        Price.Props memory longTokenPrice,
        Price.Props memory shortTokenPrice,
        bytes32 pnlFactorType,
        bool maximize
    ) external view returns (int256, MarketPoolValueInfo.Props memory) {
        uint256 supply = getMarketTokenSupply(MarketToken(payable(market.marketToken)));

        MarketPoolValueInfo.Props memory poolValueInfo = getPoolValueInfo(
            dataStore,
            market,
            indexTokenPrice,
            longTokenPrice,
            shortTokenPrice,
            pnlFactorType,
            maximize
        );

        // if the supply is zero then treat the market token price as 1 USD
        if (supply == 0) {
            return (Precision.FLOAT_PRECISION.toInt256(), poolValueInfo);
        }

        if (poolValueInfo.poolValue == 0) { return (0, poolValueInfo); }

        int256 marketTokenPrice = Precision.mulDiv(Precision.WEI_PRECISION, poolValueInfo.poolValue, supply);
        return (marketTokenPrice, poolValueInfo);
    }

    // @dev get the total supply of the marketToken
    // @param marketToken the marketToken
    // @return the total supply of the marketToken
    function getMarketTokenSupply(MarketToken marketToken) internal view returns (uint256) {
        return marketToken.totalSupply();
    }

    // @dev get the opposite token of the market
    // if the inputToken is the longToken return the shortToken and vice versa
    // @param inputToken the input token
    // @param market the market values
    // @return the opposite token
    function getOppositeToken(address inputToken, Market.Props memory market) internal pure returns (address) {
        if (inputToken == market.longToken) {
            return market.shortToken;
        }

        if (inputToken == market.shortToken) {
            return market.longToken;
        }

        revert Errors.UnableToGetOppositeToken(inputToken, market.marketToken);
    }

    function validateSwapMarket(DataStore dataStore, address marketAddress) internal view {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateSwapMarket(dataStore, market);
    }

    function validateSwapMarket(DataStore dataStore, Market.Props memory market) internal view {
        validateEnabledMarket(dataStore, market);

        if (market.longToken == market.shortToken) {
            revert Errors.InvalidSwapMarket(market.marketToken);
        }
    }

    // @dev get the token price from the stored MarketPrices
    // @param token the token to get the price for
    // @param the market values
    // @param the market token prices
    // @return the token price from the stored MarketPrices
    function getCachedTokenPrice(address token, Market.Props memory market, MarketPrices memory prices) internal pure returns (Price.Props memory) {
        if (token == market.longToken) {
            return prices.longTokenPrice;
        }
        if (token == market.shortToken) {
            return prices.shortTokenPrice;
        }
        if (token == market.indexToken) {
            return prices.indexTokenPrice;
        }

        revert Errors.UnableToGetCachedTokenPrice(token, market.marketToken);
    }

    // @dev return the primary prices for the market tokens
    // @param oracle Oracle
    // @param market the market values
    function getMarketPrices(Oracle oracle, Market.Props memory market) internal view returns (MarketPrices memory) {
        return MarketPrices(
            oracle.getPrimaryPrice(market.indexToken),
            oracle.getPrimaryPrice(market.longToken),
            oracle.getPrimaryPrice(market.shortToken)
        );
    }

    // @dev get the usd value of either the long or short tokens in the pool
    // without accounting for the pnl of open positions
    // @param dataStore DataStore
    // @param market the market values
    // @param prices the prices of the market tokens
    // @param whether to return the value for the long or short token
    // @return the usd value of either the long or short tokens in the pool
    function getPoolUsdWithoutPnl(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong,
        bool maximize
    ) internal view returns (uint256) {
        address token = isLong ? market.longToken : market.shortToken;
        // note that if it is a single token market, the poolAmount returned will be
        // the amount of tokens in the pool divided by 2
        uint256 poolAmount = getPoolAmount(dataStore, market, token);
        uint256 tokenPrice;

        if (maximize) {
            tokenPrice = isLong ? prices.longTokenPrice.max : prices.shortTokenPrice.max;
        } else {
            tokenPrice = isLong ? prices.longTokenPrice.min : prices.shortTokenPrice.min;
        }

        return poolAmount * tokenPrice;
    }

    // @dev get the USD value of a pool
    // the value of a pool is the worth of the liquidity provider tokens in the pool - pending trader pnl
    // we use the token index prices to calculate this and ignore price impact since if all positions were closed the
    // net price impact should be zero
    // @param dataStore DataStore
    // @param market the market values
    // @param longTokenPrice price of the long token
    // @param shortTokenPrice price of the short token
    // @param indexTokenPrice price of the index token
    // @param maximize whether to maximize or minimize the pool value
    // @return the value information of a pool
    function getPoolValueInfo(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        Price.Props memory longTokenPrice,
        Price.Props memory shortTokenPrice,
        bytes32 pnlFactorType,
        bool maximize
    ) public view returns (MarketPoolValueInfo.Props memory) {
        MarketPoolValueInfo.Props memory result;

        result.longTokenAmount = getPoolAmount(dataStore, market, market.longToken);
        result.shortTokenAmount = getPoolAmount(dataStore, market, market.shortToken);

        result.longTokenUsd = result.longTokenAmount * longTokenPrice.pickPrice(maximize);
        result.shortTokenUsd = result.shortTokenAmount * shortTokenPrice.pickPrice(maximize);

        result.poolValue = (result.longTokenUsd + result.shortTokenUsd).toInt256();

        MarketPrices memory prices = MarketPrices(
            indexTokenPrice,
            longTokenPrice,
            shortTokenPrice
        );

        result.totalBorrowingFees = getTotalPendingBorrowingFees(
            dataStore,
            market,
            prices,
            true
        );

        result.totalBorrowingFees += getTotalPendingBorrowingFees(
            dataStore,
            market,
            prices,
            false
        );

        result.borrowingFeePoolFactor = Precision.FLOAT_PRECISION - dataStore.getUint(Keys.BORROWING_FEE_RECEIVER_FACTOR);
        result.poolValue += Precision.applyFactor(result.totalBorrowingFees, result.borrowingFeePoolFactor).toInt256();

        // !maximize should be used for net pnl as a larger pnl leads to a smaller pool value
        // and a smaller pnl leads to a larger pool value
        //
        // while positions will always be closed at the less favourable price
        // using the inverse of maximize for the getPnl calls would help prevent
        // gaming of market token values by increasing the spread
        //
        // liquidations could be triggerred by manipulating a large spread but
        // that should be more difficult to execute

        result.longPnl = getPnl(
            dataStore,
            market,
            indexTokenPrice,
            true, // isLong
            !maximize // maximize
        );

        result.longPnl = getCappedPnl(
            dataStore,
            market.marketToken,
            true,
            result.longPnl,
            result.longTokenUsd,
            pnlFactorType
        );

        result.shortPnl = getPnl(
            dataStore,
            market,
            indexTokenPrice,
            false, // isLong
            !maximize // maximize
        );

        result.shortPnl = getCappedPnl(
            dataStore,
            market.marketToken,
            false,
            result.shortPnl,
            result.shortTokenUsd,
            pnlFactorType
        );

        result.netPnl = result.longPnl + result.shortPnl;
        result.poolValue = result.poolValue - result.netPnl;

        result.impactPoolAmount = getNextPositionImpactPoolAmount(dataStore, market.marketToken);
        // use !maximize for pickPrice since the impactPoolUsd is deducted from the poolValue
        uint256 impactPoolUsd = result.impactPoolAmount * indexTokenPrice.pickPrice(!maximize);

        result.poolValue -= impactPoolUsd.toInt256();

        return result;
    }

    // @dev get the net pending pnl for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param indexTokenPrice the price of the index token
    // @param maximize whether to maximize or minimize the net pnl
    // @return the net pending pnl for a market
    function getNetPnl(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        bool maximize
    ) internal view returns (int256) {
        int256 longPnl = getPnl(dataStore, market, indexTokenPrice, true, maximize);
        int256 shortPnl = getPnl(dataStore, market, indexTokenPrice, false, maximize);

        return longPnl + shortPnl;
    }

    // @dev get the capped pending pnl for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check for the long or short side
    // @param pnl the uncapped pnl of the market
    // @param poolUsd the USD value of the pool
    // @param pnlFactorType the pnl factor type to use
    function getCappedPnl(
        DataStore dataStore,
        address market,
        bool isLong,
        int256 pnl,
        uint256 poolUsd,
        bytes32 pnlFactorType
    ) internal view returns (int256) {
        if (pnl < 0) { return pnl; }

        uint256 maxPnlFactor = getMaxPnlFactor(dataStore, pnlFactorType, market, isLong);
        int256 maxPnl = Precision.applyFactor(poolUsd, maxPnlFactor).toInt256();

        return pnl > maxPnl ? maxPnl : pnl;
    }

    // @dev get the pending pnl for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param indexTokenPrice the price of the index token
    // @param isLong whether to check for the long or short side
    // @param maximize whether to maximize or minimize the pnl
    function getPnl(
        DataStore dataStore,
        Market.Props memory market,
        uint256 indexTokenPrice,
        bool isLong,
        bool maximize
    ) internal view returns (int256) {
        Price.Props memory _indexTokenPrice = Price.Props(indexTokenPrice, indexTokenPrice);

        return getPnl(
            dataStore,
            market,
            _indexTokenPrice,
            isLong,
            maximize
        );
    }

    // @dev get the pending pnl for a market for either longs or shorts
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param indexTokenPrice the price of the index token
    // @param isLong whether to get the pnl for longs or shorts
    // @param maximize whether to maximize or minimize the net pnl
    // @return the pending pnl for a market for either longs or shorts
    function getPnl(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        bool isLong,
        bool maximize
    ) internal view returns (int256) {
        int256 openInterest = getOpenInterest(dataStore, market, isLong).toInt256();
        uint256 openInterestInTokens = getOpenInterestInTokens(dataStore, market, isLong);
        if (openInterest == 0 || openInterestInTokens == 0) {
            return 0;
        }

        uint256 price = indexTokenPrice.pickPriceForPnl(isLong, maximize);

        // openInterest is the cost of all positions, openInterestValue is the current worth of all positions
        int256 openInterestValue = (openInterestInTokens * price).toInt256();
        int256 pnl = isLong ? openInterestValue - openInterest : openInterest - openInterestValue;

        return pnl;
    }

    // @dev get the amount of tokens in the pool
    // @param dataStore DataStore
    // @param market the market to check
    // @param token the token to check
    // @return the amount of tokens in the pool
    function getPoolAmount(DataStore dataStore, Market.Props memory market, address token) internal view returns (uint256) {
        /* Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress); */
        // if the longToken and shortToken are the same, return half of the token amount, so that
        // calculations of pool value, etc would be correct
        uint256 divisor = getPoolDivisor(market.longToken, market.shortToken);
        return dataStore.getUint(Keys.poolAmountKey(market.marketToken, token)) / divisor;
    }

    // @dev get the max amount of tokens allowed to be in the pool
    // @param dataStore DataStore
    // @param market the market to check
    // @param token the token to check
    // @return the max amount of tokens that are allowed in the pool
    function getMaxPoolAmount(DataStore dataStore, address market, address token) internal view returns (uint256) {
        return dataStore.getUint(Keys.maxPoolAmountKey(market, token));
    }

    function getMaxPoolUsdForDeposit(DataStore dataStore, address market, address token) internal view returns (uint256) {
        return dataStore.getUint(Keys.maxPoolUsdForDepositKey(market, token));
    }

    function getUsageFactor(
        DataStore dataStore,
        Market.Props memory market,
        bool isLong,
        uint256 reservedUsd,
        uint256 poolUsd
    ) internal view returns (uint256) {
        uint256 reserveFactor = getOpenInterestReserveFactor(dataStore, market.marketToken, isLong);
        uint256 maxReservedUsd = Precision.applyFactor(poolUsd, reserveFactor);
        uint256 reserveUsageFactor = Precision.toFactor(reservedUsd, maxReservedUsd);

        return reserveUsageFactor;
    }

    // @dev get the max open interest allowed for the market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether this is for the long or short side
    // @return the max open interest allowed for the market
    function getMaxOpenInterest(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.maxOpenInterestKey(market, isLong));
    }

    // @dev increment the claimable collateral amount
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to increment the claimable collateral for
    // @param token the claimable token
    // @param account the account to increment the claimable collateral for
    // @param delta the amount to increment
    function incrementClaimableCollateralAmount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        address account,
        uint256 delta
    ) internal {
        uint256 divisor = dataStore.getUint(Keys.CLAIMABLE_COLLATERAL_TIME_DIVISOR);
        uint256 timeKey = Chain.currentTimestamp() / divisor;

        uint256 nextValue = dataStore.incrementUint(
            Keys.claimableCollateralAmountKey(market, token, timeKey, account),
            delta
        );

        uint256 nextPoolValue = dataStore.incrementUint(
            Keys.claimableCollateralAmountKey(market, token),
            delta
        );

        MarketEventUtils.emitClaimableCollateralUpdated(
            eventEmitter,
            market,
            token,
            timeKey,
            account,
            delta,
            nextValue,
            nextPoolValue
        );
    }

    // @dev increment the claimable funding amount
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the trading market
    // @param token the claimable token
    // @param account the account to increment for
    // @param delta the amount to increment
    function incrementClaimableFundingAmount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        address account,
        uint256 delta
    ) internal {
        uint256 nextValue = dataStore.incrementUint(
            Keys.claimableFundingAmountKey(market, token, account),
            delta
        );

        uint256 nextPoolValue = dataStore.incrementUint(
            Keys.claimableFundingAmountKey(market, token),
            delta
        );

        MarketEventUtils.emitClaimableFundingUpdated(
            eventEmitter,
            market,
            token,
            account,
            delta,
            nextValue,
            nextPoolValue
        );
    }

    // @dev claim funding fees
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to claim for
    // @param token the token to claim
    // @param account the account to claim for
    // @param receiver the receiver to send the amount to
    function claimFundingFees(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        address account,
        address receiver
    ) internal returns (uint256) {
        bytes32 key = Keys.claimableFundingAmountKey(market, token, account);

        uint256 claimableAmount = dataStore.getUint(key);
        dataStore.setUint(key, 0);

        uint256 nextPoolValue = dataStore.decrementUint(
            Keys.claimableFundingAmountKey(market, token),
            claimableAmount
        );

        MarketToken(payable(market)).transferOut(
            token,
            receiver,
            claimableAmount
        );

        validateMarketTokenBalance(dataStore, market);

        MarketEventUtils.emitFundingFeesClaimed(
            eventEmitter,
            market,
            token,
            account,
            receiver,
            claimableAmount,
            nextPoolValue
        );

        return claimableAmount;
    }

    function batchClaimCollateral(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address[] memory markets,
        address[] memory tokens,
        uint256[] memory timeKeys,
        address receiver,
        address account
    ) internal returns (uint256[] memory) {
        if (markets.length != tokens.length || tokens.length != timeKeys.length) {
            revert Errors.InvalidClaimCollateralInput(markets.length, tokens.length, timeKeys.length);
        }

        FeatureUtils.validateFeature(dataStore, Keys.claimCollateralFeatureDisabledKey(address(this)));

        AccountUtils.validateReceiver(receiver);

        uint256[] memory claimedAmounts = new uint256[](markets.length);

        for (uint256 i; i < markets.length; i++) {
            claimedAmounts[i] = MarketUtils.claimCollateral(
                dataStore,
                eventEmitter,
                markets[i],
                tokens[i],
                timeKeys[i],
                account,
                receiver
            );
        }

        return claimedAmounts;
    }

    // @dev claim collateral
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to claim for
    // @param token the token to claim
    // @param timeKey the time key
    // @param account the account to claim for
    // @param receiver the receiver to send the amount to
    function claimCollateral(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 timeKey,
        address account,
        address receiver
    ) internal returns (uint256) {
        uint256 claimableAmount = dataStore.getUint(Keys.claimableCollateralAmountKey(market, token, timeKey, account));

        uint256 claimableFactor = _getClaimableFactor(dataStore, market, token, timeKey, account);

        if (claimableFactor > Precision.FLOAT_PRECISION) {
            revert Errors.InvalidClaimableFactor(claimableFactor);
        }

        uint256 claimedAmount = dataStore.getUint(Keys.claimedCollateralAmountKey(market, token, timeKey, account));

        uint256 adjustedClaimableAmount = Precision.applyFactor(claimableAmount, claimableFactor);
        if (adjustedClaimableAmount <= claimedAmount) {
            revert Errors.CollateralAlreadyClaimed(adjustedClaimableAmount, claimedAmount);
        }

        uint256 amountToBeClaimed = adjustedClaimableAmount - claimedAmount;

        dataStore.setUint(
            Keys.claimedCollateralAmountKey(market, token, timeKey, account),
            adjustedClaimableAmount
        );

        uint256 nextPoolValue = dataStore.decrementUint(
            Keys.claimableCollateralAmountKey(market, token),
            amountToBeClaimed
        );

        MarketToken(payable(market)).transferOut(
            token,
            receiver,
            amountToBeClaimed
        );

        validateMarketTokenBalance(dataStore, market);

        MarketEventUtils.emitCollateralClaimed(
            eventEmitter,
            market,
            token,
            timeKey,
            account,
            receiver,
            amountToBeClaimed,
            nextPoolValue
        );

        return amountToBeClaimed;
    }

    function _getClaimableFactor(
        DataStore dataStore,
        address market,
        address token,
        uint256 timeKey,
        address account
    ) internal view returns (uint256) {
        uint256 claimableFactorForTime = dataStore.getUint(Keys.claimableCollateralFactorKey(market, token, timeKey));
        uint256 claimableFactorForAccount = dataStore.getUint(Keys.claimableCollateralFactorKey(market, token, timeKey, account));
        uint256 claimableFactor = claimableFactorForTime > claimableFactorForAccount
            ? claimableFactorForTime
            : claimableFactorForAccount;

        // if the divisor is changed the timeDiff calculation would no longer be accurate
        uint256 divisor = dataStore.getUint(Keys.CLAIMABLE_COLLATERAL_TIME_DIVISOR);

        uint256 claimableReductionFactor = dataStore.getUint(Keys.claimableCollateralReductionFactorKey(market, token, timeKey, account));
        uint256 timeDiff = Chain.currentTimestamp() - timeKey * divisor;
        uint256 claimableCollateralDelay = dataStore.getUint(Keys.CLAIMABLE_COLLATERAL_DELAY);

        if (claimableFactor == 0 && claimableReductionFactor == 0 && timeDiff > claimableCollateralDelay) {
            claimableFactor = Precision.FLOAT_PRECISION;
        }

        if (claimableFactor > claimableReductionFactor) {
            claimableFactor -= claimableReductionFactor;
        } else {
            claimableFactor = 0;
        }

        return claimableFactor;
    }

    // @dev apply a delta to the pool amount
    // validatePoolAmount is not called in this function since applyDeltaToPoolAmount
    // is called when receiving fees
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param token the token to apply to
    // @param delta the delta amount
    function applyDeltaToPoolAmount(
        DataStore dataStore,
        EventEmitter eventEmitter,
        Market.Props memory market,
        address token,
        int256 delta
    ) internal returns (uint256) {
        uint256 nextValue = dataStore.applyDeltaToUint(
            Keys.poolAmountKey(market.marketToken, token),
            delta,
            "Invalid state, negative poolAmount"
        );

        applyDeltaToVirtualInventoryForSwaps(
            dataStore,
            eventEmitter,
            market,
            token,
            delta
        );

        MarketEventUtils.emitPoolAmountUpdated(eventEmitter, market.marketToken, token, delta, nextValue);

        return nextValue;
    }

    function getAdjustedSwapImpactFactor(DataStore dataStore, address market, bool isPositive) internal view returns (uint256) {
        (uint256 positiveImpactFactor, uint256 negativeImpactFactor) = getAdjustedSwapImpactFactors(dataStore, market);

        return isPositive ? positiveImpactFactor : negativeImpactFactor;
    }

    function getAdjustedSwapImpactFactors(DataStore dataStore, address market) internal view returns (uint256, uint256) {
        uint256 positiveImpactFactor = dataStore.getUint(Keys.swapImpactFactorKey(market, true));
        uint256 negativeImpactFactor = dataStore.getUint(Keys.swapImpactFactorKey(market, false));

        // if the positive impact factor is more than the negative impact factor, positions could be opened
        // and closed immediately for a profit if the difference is sufficient to cover the position fees
        if (positiveImpactFactor > negativeImpactFactor) {
            positiveImpactFactor = negativeImpactFactor;
        }

        return (positiveImpactFactor, negativeImpactFactor);
    }

    function getAdjustedPositionImpactFactor(DataStore dataStore, address market, bool isPositive) internal view returns (uint256) {
        (uint256 positiveImpactFactor, uint256 negativeImpactFactor) = getAdjustedPositionImpactFactors(dataStore, market);

        return isPositive ? positiveImpactFactor : negativeImpactFactor;
    }

    function getAdjustedPositionImpactFactors(DataStore dataStore, address market) internal view returns (uint256, uint256) {
        uint256 positiveImpactFactor = dataStore.getUint(Keys.positionImpactFactorKey(market, true));
        uint256 negativeImpactFactor = dataStore.getUint(Keys.positionImpactFactorKey(market, false));

        // if the positive impact factor is more than the negative impact factor, positions could be opened
        // and closed immediately for a profit if the difference is sufficient to cover the position fees
        if (positiveImpactFactor > negativeImpactFactor) {
            positiveImpactFactor = negativeImpactFactor;
        }

        return (positiveImpactFactor, negativeImpactFactor);
    }

    // @dev cap the input priceImpactUsd by the available amount in the position impact pool
    // @param dataStore DataStore
    // @param market the trading market
    // @param indexTokenPrice the price of the token
    // @param priceImpactUsd the calculated USD price impact
    // @return the capped priceImpactUsd
    function capPositiveImpactUsdByPositionImpactPool(
        DataStore dataStore,
        address market,
        Price.Props memory indexTokenPrice,
        int256 priceImpactUsd
    ) internal view returns (int256) {
        if (priceImpactUsd < 0) {
            return priceImpactUsd;
        }

        uint256 impactPoolAmount = getPositionImpactPoolAmount(dataStore, market);
        // use indexTokenPrice.min to maximize the position impact pool reduction
        int256 maxPriceImpactUsdBasedOnImpactPool = (impactPoolAmount * indexTokenPrice.min).toInt256();

        if (priceImpactUsd > maxPriceImpactUsdBasedOnImpactPool) {
            priceImpactUsd = maxPriceImpactUsdBasedOnImpactPool;
        }

        return priceImpactUsd;
    }

    // @dev cap the input priceImpactUsd by the max positive position impact factor
    // @param dataStore DataStore
    // @param market the trading market
    // @param priceImpactUsd the calculated USD price impact
    // @param sizeDeltaUsd the size by which the position is increased/decreased
    // @return the capped priceImpactUsd
    function capPositiveImpactUsdByMaxPositionImpact(
        DataStore dataStore,
        address market,
        int256 priceImpactUsd,
        uint256 sizeDeltaUsd
    ) internal view returns (int256) {
        if (priceImpactUsd < 0) {
            return priceImpactUsd;
        }

        uint256 maxPriceImpactFactor = getMaxPositionImpactFactor(dataStore, market, true);
        int256 maxPriceImpactUsdBasedOnMaxPriceImpactFactor = Precision.applyFactor(sizeDeltaUsd, maxPriceImpactFactor).toInt256();

        // capped by the positive price impact
        if (priceImpactUsd > maxPriceImpactUsdBasedOnMaxPriceImpactFactor) {
            priceImpactUsd = maxPriceImpactUsdBasedOnMaxPriceImpactFactor;
        }

        return priceImpactUsd;
    }

    // @dev get the position impact pool amount
    // @param dataStore DataStore
    // @param market the market to check
    // @return the position impact pool amount
    function getPositionImpactPoolAmount(DataStore dataStore, address market) internal view returns (uint256) {
        return dataStore.getUint(Keys.positionImpactPoolAmountKey(market));
    }

    // @dev get the swap impact pool amount
    // @param dataStore DataStore
    // @param market the market to check
    // @param token the token to check
    // @return the swap impact pool amount
    function getSwapImpactPoolAmount(DataStore dataStore, address market, address token) internal view returns (uint256) {
        return dataStore.getUint(Keys.swapImpactPoolAmountKey(market, token));
    }

    // @dev apply a delta to the swap impact pool
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param token the token to apply to
    // @param delta the delta amount
    function applyDeltaToSwapImpactPool(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        int256 delta
    ) internal returns (uint256) {
        uint256 nextValue = dataStore.applyBoundedDeltaToUint(
            Keys.swapImpactPoolAmountKey(market, token),
            delta
        );

        MarketEventUtils.emitSwapImpactPoolAmountUpdated(eventEmitter, market, token, delta, nextValue);

        return nextValue;
    }

    // @dev apply a delta to the position impact pool
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param delta the delta amount
    function applyDeltaToPositionImpactPool(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        int256 delta
    ) internal returns (uint256) {
        uint256 nextValue = dataStore.applyBoundedDeltaToUint(
            Keys.positionImpactPoolAmountKey(market),
            delta
        );

        MarketEventUtils.emitPositionImpactPoolAmountUpdated(eventEmitter, market, delta, nextValue);

        return nextValue;
    }

    // @dev apply a delta to the open interest
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param collateralToken the collateralToken to apply to
    // @param isLong whether to apply to the long or short side
    // @param delta the delta amount
    function applyDeltaToOpenInterest(
        DataStore dataStore,
        EventEmitter eventEmitter,
        Market.Props memory market,
        address collateralToken,
        bool isLong,
        int256 delta
    ) internal returns (uint256) {
        if (market.indexToken == address(0)) {
            revert Errors.OpenInterestCannotBeUpdatedForSwapOnlyMarket(market.marketToken);
        }

        uint256 nextValue = dataStore.applyDeltaToUint(
            Keys.openInterestKey(market.marketToken, collateralToken, isLong),
            delta,
            "Invalid state: negative open interest"
        );

        // if the open interest for longs is increased then tokens were virtually bought from the pool
        // so the virtual inventory should be decreased
        // if the open interest for longs is decreased then tokens were virtually sold to the pool
        // so the virtual inventory should be increased
        // if the open interest for shorts is increased then tokens were virtually sold to the pool
        // so the virtual inventory should be increased
        // if the open interest for shorts is decreased then tokens were virtually bought from the pool
        // so the virtual inventory should be decreased
        applyDeltaToVirtualInventoryForPositions(
            dataStore,
            eventEmitter,
            market.indexToken,
            isLong ? -delta : delta
        );

        if (delta > 0) {
            validateOpenInterest(
                dataStore,
                market,
                isLong
            );
        }

        MarketEventUtils.emitOpenInterestUpdated(eventEmitter, market.marketToken, collateralToken, isLong, delta, nextValue);

        return nextValue;
    }

    // @dev apply a delta to the open interest in tokens
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param collateralToken the collateralToken to apply to
    // @param isLong whether to apply to the long or short side
    // @param delta the delta amount
    function applyDeltaToOpenInterestInTokens(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        int256 delta
    ) internal returns (uint256) {
        uint256 nextValue = dataStore.applyDeltaToUint(
            Keys.openInterestInTokensKey(market, collateralToken, isLong),
            delta,
            "Invalid state: negative open interest in tokens"
        );

        MarketEventUtils.emitOpenInterestInTokensUpdated(eventEmitter, market, collateralToken, isLong, delta, nextValue);

        return nextValue;
    }

    // @dev apply a delta to the collateral sum
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param collateralToken the collateralToken to apply to
    // @param isLong whether to apply to the long or short side
    // @param delta the delta amount
    function applyDeltaToCollateralSum(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        int256 delta
    ) internal returns (uint256) {
        uint256 nextValue = dataStore.applyDeltaToUint(
            Keys.collateralSumKey(market, collateralToken, isLong),
            delta,
            "Invalid state: negative collateralSum"
        );

        MarketEventUtils.emitCollateralSumUpdated(eventEmitter, market, collateralToken, isLong, delta, nextValue);

        return nextValue;
    }

    // @dev update the funding state
    // @param dataStore DataStore
    // @param market the market to update
    // @param prices the prices of the market tokens
    function updateFundingState(
        DataStore dataStore,
        EventEmitter eventEmitter,
        Market.Props memory market,
        MarketPrices memory prices
    ) external {
        GetNextFundingAmountPerSizeResult memory result = getNextFundingAmountPerSize(dataStore, market, prices);

        applyDeltaToFundingFeeAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.longToken,
            true,
            result.fundingFeeAmountPerSizeDelta.long.longToken
        );

        applyDeltaToFundingFeeAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.longToken,
            false,
            result.fundingFeeAmountPerSizeDelta.short.longToken
        );

        applyDeltaToFundingFeeAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.shortToken,
            true,
            result.fundingFeeAmountPerSizeDelta.long.shortToken
        );

        applyDeltaToFundingFeeAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.shortToken,
            false,
            result.fundingFeeAmountPerSizeDelta.short.shortToken
        );

        applyDeltaToClaimableFundingAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.longToken,
            true,
            result.claimableFundingAmountPerSizeDelta.long.longToken
        );

        applyDeltaToClaimableFundingAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.longToken,
            false,
            result.claimableFundingAmountPerSizeDelta.short.longToken
        );

        applyDeltaToClaimableFundingAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.shortToken,
            true,
            result.claimableFundingAmountPerSizeDelta.long.shortToken
        );

        applyDeltaToClaimableFundingAmountPerSize(
            dataStore,
            eventEmitter,
            market.marketToken,
            market.shortToken,
            false,
            result.claimableFundingAmountPerSizeDelta.short.shortToken
        );

        setSavedFundingFactorPerSecond(dataStore, market.marketToken, result.nextSavedFundingFactorPerSecond);

        dataStore.setUint(Keys.fundingUpdatedAtKey(market.marketToken), Chain.currentTimestamp());

        MarketEventUtils.emitFunding(
            eventEmitter,
            market.marketToken,
            result.fundingFactorPerSecond
        );
    }

    // @dev get the next funding amount per size values
    // @param dataStore DataStore
    // @param prices the prices of the market tokens
    // @param market the market to update
    // @param longToken the market's long token
    // @param shortToken the market's short token
    function getNextFundingAmountPerSize(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices
    ) internal view returns (GetNextFundingAmountPerSizeResult memory) {
        GetNextFundingAmountPerSizeResult memory result;
        GetNextFundingAmountPerSizeCache memory cache;

        uint256 divisor = getPoolDivisor(market.longToken, market.shortToken);

        // get the open interest values by long / short and by collateral used
        cache.openInterest.long.longToken = getOpenInterest(dataStore, market.marketToken, market.longToken, true, divisor);
        cache.openInterest.long.shortToken = getOpenInterest(dataStore, market.marketToken, market.shortToken, true, divisor);
        cache.openInterest.short.longToken = getOpenInterest(dataStore, market.marketToken, market.longToken, false, divisor);
        cache.openInterest.short.shortToken = getOpenInterest(dataStore, market.marketToken, market.shortToken, false, divisor);

        // sum the open interest values to get the total long and short open interest values
        cache.longOpenInterest = cache.openInterest.long.longToken + cache.openInterest.long.shortToken;
        cache.shortOpenInterest = cache.openInterest.short.longToken + cache.openInterest.short.shortToken;

        // if either long or short open interest is zero, then funding should not be updated
        // as there would not be any user to pay the funding to
        if (cache.longOpenInterest == 0 || cache.shortOpenInterest == 0) {
            return result;
        }

        // if the blockchain is not progressing / a market is disabled, funding fees
        // will continue to accumulate
        // this should be a rare occurrence so funding fees are not adjusted for this case
        cache.durationInSeconds = getSecondsSinceFundingUpdated(dataStore, market.marketToken);

        (result.fundingFactorPerSecond, result.longsPayShorts, result.nextSavedFundingFactorPerSecond) = getNextFundingFactorPerSecond(
            dataStore,
            market.marketToken,
            cache.longOpenInterest,
            cache.shortOpenInterest,
            cache.durationInSeconds
        );

        cache.sizeOfPayingSide = result.longsPayShorts ? cache.longOpenInterest : cache.shortOpenInterest;

        // for single token markets, if there is $200,000 long open interest
        // and $100,000 short open interest and if the fundingUsd is $8:
        // fundingUsdForLongCollateral: $4
        // fundingUsdForShortCollateral: $4
        // fundingFeeAmountPerSizeDelta.long.longToken: 4 / 100,000
        // fundingFeeAmountPerSizeDelta.long.shortToken: 4 / 100,000
        // claimableFundingAmountPerSizeDelta.short.longToken: 4 / 100,000
        // claimableFundingAmountPerSizeDelta.short.shortToken: 4 / 100,000
        //
        // the divisor for fundingFeeAmountPerSizeDelta is 100,000 because the
        // cache.openInterest.long.longOpenInterest and cache.openInterest.long.shortOpenInterest is divided by 2
        //
        // when the fundingFeeAmountPerSize value is incremented, it would be incremented twice:
        // 4 / 100,000 + 4 / 100,000 = 8 / 100,000
        //
        // since the actual long open interest is $200,000, this would result in a total of 8 / 100,000 * 200,000 = $16 being charged
        //
        // when the claimableFundingAmountPerSize value is incremented, it would similarly be incremented twice:
        // 4 / 100,000 + 4 / 100,000 = 8 / 100,000
        //
        // when calculating the amount to be claimed, the longTokenClaimableFundingAmountPerSize and shortTokenClaimableFundingAmountPerSize
        // are compared against the market's claimableFundingAmountPerSize for the longToken and claimableFundingAmountPerSize for the shortToken
        //
        // since both these values will be duplicated, the amount claimable would be:
        // (8 / 100,000 + 8 / 100,000) * 100,000 = $16
        //
        // due to these, the fundingUsd should be divided by the divisor

        cache.fundingUsd = Precision.applyFactor(cache.sizeOfPayingSide, cache.durationInSeconds * result.fundingFactorPerSecond);
        cache.fundingUsd = cache.fundingUsd / divisor;

        // split the fundingUsd value by long and short collateral
        // e.g. if the fundingUsd value is $500, and there is $1000 of long open interest using long collateral and $4000 of long open interest
        // with short collateral, then $100 of funding fees should be paid from long positions using long collateral, $400 of funding fees
        // should be paid from long positions using short collateral
        // short positions should receive $100 of funding fees in long collateral and $400 of funding fees in short collateral
        if (result.longsPayShorts) {
            cache.fundingUsdForLongCollateral = Precision.mulDiv(cache.fundingUsd, cache.openInterest.long.longToken, cache.longOpenInterest);
            cache.fundingUsdForShortCollateral = Precision.mulDiv(cache.fundingUsd, cache.openInterest.long.shortToken, cache.longOpenInterest);
        } else {
            cache.fundingUsdForLongCollateral = Precision.mulDiv(cache.fundingUsd, cache.openInterest.short.longToken, cache.shortOpenInterest);
            cache.fundingUsdForShortCollateral = Precision.mulDiv(cache.fundingUsd, cache.openInterest.short.shortToken, cache.shortOpenInterest);
        }

        // calculate the change in funding amount per size values
        // for example, if the fundingUsdForLongCollateral is $100, the longToken price is $2000, the longOpenInterest is $10,000, shortOpenInterest is $5000
        // if longs pay shorts then the fundingFeeAmountPerSize.long.longToken should be increased by 0.05 tokens per $10,000 or 0.000005 tokens per $1
        // the claimableFundingAmountPerSize.short.longToken should be increased by 0.05 tokens per $5000 or 0.00001 tokens per $1
        if (result.longsPayShorts) {
            // use the same longTokenPrice.max and shortTokenPrice.max to calculate the amount to be paid and received
            // positions only pay funding in the position's collateral token
            // so the fundingUsdForLongCollateral is divided by the total long open interest for long positions using the longToken as collateral
            // and the fundingUsdForShortCollateral is divided by the total long open interest for long positions using the shortToken as collateral
            result.fundingFeeAmountPerSizeDelta.long.longToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForLongCollateral,
                cache.openInterest.long.longToken,
                prices.longTokenPrice.max,
                true // roundUpMagnitude
            );

            result.fundingFeeAmountPerSizeDelta.long.shortToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForShortCollateral,
                cache.openInterest.long.shortToken,
                prices.shortTokenPrice.max,
                true // roundUpMagnitude
            );

            // positions receive funding in both the longToken and shortToken
            // so the fundingUsdForLongCollateral and fundingUsdForShortCollateral is divided by the total short open interest
            result.claimableFundingAmountPerSizeDelta.short.longToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForLongCollateral,
                cache.shortOpenInterest,
                prices.longTokenPrice.max,
                false // roundUpMagnitude
            );

            result.claimableFundingAmountPerSizeDelta.short.shortToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForShortCollateral,
                cache.shortOpenInterest,
                prices.shortTokenPrice.max,
                false // roundUpMagnitude
            );
        } else {
            // use the same longTokenPrice.max and shortTokenPrice.max to calculate the amount to be paid and received
            // positions only pay funding in the position's collateral token
            // so the fundingUsdForLongCollateral is divided by the total short open interest for short positions using the longToken as collateral
            // and the fundingUsdForShortCollateral is divided by the total short open interest for short positions using the shortToken as collateral
            result.fundingFeeAmountPerSizeDelta.short.longToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForLongCollateral,
                cache.openInterest.short.longToken,
                prices.longTokenPrice.max,
                true // roundUpMagnitude
            );

            result.fundingFeeAmountPerSizeDelta.short.shortToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForShortCollateral,
                cache.openInterest.short.shortToken,
                prices.shortTokenPrice.max,
                true // roundUpMagnitude
            );

            // positions receive funding in both the longToken and shortToken
            // so the fundingUsdForLongCollateral and fundingUsdForShortCollateral is divided by the total long open interest
            result.claimableFundingAmountPerSizeDelta.long.longToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForLongCollateral,
                cache.longOpenInterest,
                prices.longTokenPrice.max,
                false // roundUpMagnitude
            );

            result.claimableFundingAmountPerSizeDelta.long.shortToken = getFundingAmountPerSizeDelta(
                cache.fundingUsdForShortCollateral,
                cache.longOpenInterest,
                prices.shortTokenPrice.max,
                false // roundUpMagnitude
            );
        }

        return result;
    }

    // @dev get the next funding factor per second
    // in case the minFundingFactorPerSecond is not zero, and the long / short skew has flipped
    // if orders are being created frequently it is possible that the minFundingFactorPerSecond prevents
    // the nextSavedFundingFactorPerSecond from being decreased fast enough for the sign to eventually flip
    // if it is bound by minFundingFactorPerSecond
    // for that reason, only the nextFundingFactorPerSecond is bound by minFundingFactorPerSecond
    // and the nextSavedFundingFactorPerSecond is not bound by minFundingFactorPerSecond
    // @return nextFundingFactorPerSecond, longsPayShorts, nextSavedFundingFactorPerSecond
    function getNextFundingFactorPerSecond(
        DataStore dataStore,
        address market,
        uint256 longOpenInterest,
        uint256 shortOpenInterest,
        uint256 durationInSeconds
    ) internal view returns (uint256, bool, int256) {
        GetNextFundingFactorPerSecondCache memory cache;

        cache.diffUsd = Calc.diff(longOpenInterest, shortOpenInterest);
        cache.totalOpenInterest = longOpenInterest + shortOpenInterest;

        FundingConfigCache memory configCache;
        configCache.fundingIncreaseFactorPerSecond = dataStore.getUint(Keys.fundingIncreaseFactorPerSecondKey(market));

        // if the open interest difference is zero and adaptive funding
        // is not enabled, then return zero as the funding factor
        if (cache.diffUsd == 0 && configCache.fundingIncreaseFactorPerSecond == 0) {
            return (0, true, 0);
        }

        if (cache.totalOpenInterest == 0) {
            revert Errors.UnableToGetFundingFactorEmptyOpenInterest();
        }

        cache.fundingExponentFactor = getFundingExponentFactor(dataStore, market);

        cache.diffUsdAfterExponent = Precision.applyExponentFactor(cache.diffUsd, cache.fundingExponentFactor);
        cache.diffUsdToOpenInterestFactor = Precision.toFactor(cache.diffUsdAfterExponent, cache.totalOpenInterest);

        if (configCache.fundingIncreaseFactorPerSecond == 0) {
            cache.fundingFactor = getFundingFactor(dataStore, market);
            uint256 maxFundingFactorPerSecond = dataStore.getUint(Keys.maxFundingFactorPerSecondKey(market));

            // if there is no fundingIncreaseFactorPerSecond then return the static fundingFactor based on open interest difference
            uint256 fundingFactorPerSecond = Precision.applyFactor(cache.diffUsdToOpenInterestFactor, cache.fundingFactor);

            if (fundingFactorPerSecond > maxFundingFactorPerSecond) {
                fundingFactorPerSecond = maxFundingFactorPerSecond;
            }

            return (
                fundingFactorPerSecond,
                longOpenInterest > shortOpenInterest,
                0
            );
        }

        // if the savedFundingFactorPerSecond is positive then longs pay shorts
        // if the savedFundingFactorPerSecond is negative then shorts pay longs
        cache.savedFundingFactorPerSecond = getSavedFundingFactorPerSecond(dataStore, market);
        cache.savedFundingFactorPerSecondMagnitude = cache.savedFundingFactorPerSecond.abs();

        configCache.thresholdForStableFunding = dataStore.getUint(Keys.thresholdForStableFundingKey(market));
        configCache.thresholdForDecreaseFunding = dataStore.getUint(Keys.thresholdForDecreaseFundingKey(market));

        // set the default of nextSavedFundingFactorPerSecond as the savedFundingFactorPerSecond
        cache.nextSavedFundingFactorPerSecond = cache.savedFundingFactorPerSecond;

        // the default will be NoChange
        FundingRateChangeType fundingRateChangeType;

        bool isSkewTheSameDirectionAsFunding = (cache.savedFundingFactorPerSecond > 0 && longOpenInterest > shortOpenInterest) || (cache.savedFundingFactorPerSecond < 0 && shortOpenInterest > longOpenInterest);

        if (isSkewTheSameDirectionAsFunding) {
            if (cache.diffUsdToOpenInterestFactor > configCache.thresholdForStableFunding) {
                fundingRateChangeType = FundingRateChangeType.Increase;
            } else if (cache.diffUsdToOpenInterestFactor < configCache.thresholdForDecreaseFunding) {
                // if thresholdForDecreaseFunding is zero and diffUsdToOpenInterestFactor is also zero
                // then the fundingRateChangeType would be NoChange
                fundingRateChangeType = FundingRateChangeType.Decrease;
            }
        } else {
            // if the skew has changed, then the funding should increase in the opposite direction
            fundingRateChangeType = FundingRateChangeType.Increase;
        }

        if (fundingRateChangeType == FundingRateChangeType.Increase) {
            // increase funding rate
            int256 increaseValue = Precision.applyFactor(cache.diffUsdToOpenInterestFactor, configCache.fundingIncreaseFactorPerSecond).toInt256() * durationInSeconds.toInt256();

            // if there are more longs than shorts, then the savedFundingFactorPerSecond should increase
            // otherwise the savedFundingFactorPerSecond should increase in the opposite direction / decrease
            if (longOpenInterest < shortOpenInterest) {
                increaseValue = -increaseValue;
            }

            cache.nextSavedFundingFactorPerSecond = cache.savedFundingFactorPerSecond + increaseValue;
        }

        if (fundingRateChangeType == FundingRateChangeType.Decrease && cache.savedFundingFactorPerSecondMagnitude != 0) {
            configCache.fundingDecreaseFactorPerSecond = dataStore.getUint(Keys.fundingDecreaseFactorPerSecondKey(market));
            uint256 decreaseValue = configCache.fundingDecreaseFactorPerSecond * durationInSeconds;

            if (cache.savedFundingFactorPerSecondMagnitude <= decreaseValue) {
                // set the funding factor to 1 or -1 depending on the original savedFundingFactorPerSecond
                cache.nextSavedFundingFactorPerSecond = cache.savedFundingFactorPerSecond / cache.savedFundingFactorPerSecondMagnitude.toInt256();
            } else {
                // reduce the original savedFundingFactorPerSecond while keeping the original sign of the savedFundingFactorPerSecond
                int256 sign = cache.savedFundingFactorPerSecond / cache.savedFundingFactorPerSecondMagnitude.toInt256();
                cache.nextSavedFundingFactorPerSecond = (cache.savedFundingFactorPerSecondMagnitude - decreaseValue).toInt256() * sign;
            }
        }

        configCache.minFundingFactorPerSecond = dataStore.getUint(Keys.minFundingFactorPerSecondKey(market));
        configCache.maxFundingFactorPerSecond = dataStore.getUint(Keys.maxFundingFactorPerSecondKey(market));

        cache.nextSavedFundingFactorPerSecond = Calc.boundMagnitude(
            cache.nextSavedFundingFactorPerSecond,
            0,
            configCache.maxFundingFactorPerSecond
        );

        cache.nextSavedFundingFactorPerSecondWithMinBound = Calc.boundMagnitude(
            cache.nextSavedFundingFactorPerSecond,
            configCache.minFundingFactorPerSecond,
            configCache.maxFundingFactorPerSecond
        );

        return (
            cache.nextSavedFundingFactorPerSecondWithMinBound.abs(),
            cache.nextSavedFundingFactorPerSecondWithMinBound > 0,
            cache.nextSavedFundingFactorPerSecond
        );
    }

    // store funding values as token amount per (Precision.FLOAT_PRECISION_SQRT / Precision.FLOAT_PRECISION) of USD size
    function getFundingAmountPerSizeDelta(
        uint256 fundingUsd,
        uint256 openInterest,
        uint256 tokenPrice,
        bool roundUpMagnitude
    ) internal pure returns (uint256) {
        if (fundingUsd == 0 || openInterest == 0) { return 0; }

        uint256 fundingUsdPerSize = Precision.mulDiv(
            fundingUsd,
            Precision.FLOAT_PRECISION * Precision.FLOAT_PRECISION_SQRT,
            openInterest,
            roundUpMagnitude
        );

        if (roundUpMagnitude) {
            return Calc.roundUpDivision(fundingUsdPerSize, tokenPrice);
        } else {
            return fundingUsdPerSize / tokenPrice;
        }
    }

    // @dev update the cumulative borrowing factor for a market
    // @param dataStore DataStore
    // @param market the market to update
    // @param longToken the market's long token
    // @param shortToken the market's short token
    // @param prices the prices of the market tokens
    // @param isLong whether to update the long or short side
    function updateCumulativeBorrowingFactor(
        DataStore dataStore,
        EventEmitter eventEmitter,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) external {
        (/* uint256 nextCumulativeBorrowingFactor */, uint256 delta, uint256 borrowingFactorPerSecond) = getNextCumulativeBorrowingFactor(
            dataStore,
            market,
            prices,
            isLong
        );

        incrementCumulativeBorrowingFactor(
            dataStore,
            eventEmitter,
            market.marketToken,
            isLong,
            delta
        );

        dataStore.setUint(Keys.cumulativeBorrowingFactorUpdatedAtKey(market.marketToken, isLong), Chain.currentTimestamp());

        MarketEventUtils.emitBorrowing(
            eventEmitter,
            market.marketToken,
            borrowingFactorPerSecond
        );
    }

    // @dev get the ratio of pnl to pool value
    // @param dataStore DataStore
    // @param oracle Oracle
    // @param market the trading market
    // @param isLong whether to get the value for the long or short side
    // @param maximize whether to maximize the factor
    // @return (pnl of positions) / (long or short pool value)
    function getPnlToPoolFactor(
        DataStore dataStore,
        Oracle oracle,
        address market,
        bool isLong,
        bool maximize
    ) internal view returns (int256) {
        Market.Props memory _market = getEnabledMarket(dataStore, market);
        MarketPrices memory prices = MarketPrices(
            oracle.getPrimaryPrice(_market.indexToken),
            oracle.getPrimaryPrice(_market.longToken),
            oracle.getPrimaryPrice(_market.shortToken)
        );

        return getPnlToPoolFactor(dataStore, _market, prices, isLong, maximize);
    }

    // @dev get the ratio of pnl to pool value
    // @param dataStore DataStore
    // @param market the market values
    // @param prices the prices of the market tokens
    // @param isLong whether to get the value for the long or short side
    // @param maximize whether to maximize the factor
    // @return (pnl of positions) / (long or short pool value)
    function getPnlToPoolFactor(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong,
        bool maximize
    ) internal view returns (int256) {
        uint256 poolUsd = getPoolUsdWithoutPnl(dataStore, market, prices, isLong, !maximize);

        if (poolUsd == 0) {
            return 0;
        }

        int256 pnl = getPnl(
            dataStore,
            market,
            prices.indexTokenPrice,
            isLong,
            maximize
        );

        return Precision.toFactor(pnl, poolUsd);
    }

    function validateOpenInterest(
        DataStore dataStore,
        Market.Props memory market,
        bool isLong
    ) internal view {
        uint256 openInterest = getOpenInterest(dataStore, market, isLong);
        uint256 maxOpenInterest = getMaxOpenInterest(dataStore, market.marketToken, isLong);

        if (openInterest > maxOpenInterest) {
            revert Errors.MaxOpenInterestExceeded(openInterest, maxOpenInterest);
        }
    }

    // @dev validate that the pool amount is within the max allowed amount
    // @param dataStore DataStore
    // @param market the market to check
    // @param token the token to check
    function validatePoolAmount(
        DataStore dataStore,
        Market.Props memory market,
        address token
    ) internal view {
        uint256 poolAmount = getPoolAmount(dataStore, market, token);
        uint256 maxPoolAmount = getMaxPoolAmount(dataStore, market.marketToken, token);

        if (poolAmount > maxPoolAmount) {
            revert Errors.MaxPoolAmountExceeded(poolAmount, maxPoolAmount);
        }
    }

    function validatePoolUsdForDeposit(
        DataStore dataStore,
        Market.Props memory market,
        address token,
        uint256 tokenPrice
    ) internal view {
        uint256 poolAmount = getPoolAmount(dataStore, market, token);
        uint256 poolUsd = poolAmount * tokenPrice;
        uint256 maxPoolUsd = getMaxPoolUsdForDeposit(dataStore, market.marketToken, token);

        if (poolUsd > maxPoolUsd) {
            revert Errors.MaxPoolUsdForDepositExceeded(poolUsd, maxPoolUsd);
        }
    }

    // @dev validate that the amount of tokens required to be reserved
    // is below the configured threshold
    // @param dataStore DataStore
    // @param market the market values
    // @param prices the prices of the market tokens
    // @param isLong whether to check the long or short side
    function validateReserve(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) internal view {
        // poolUsd is used instead of pool amount as the indexToken may not match the longToken
        // additionally, the shortToken may not be a stablecoin
        uint256 poolUsd = getPoolUsdWithoutPnl(dataStore, market, prices, isLong, false);
        uint256 reserveFactor = getReserveFactor(dataStore, market.marketToken, isLong);
        uint256 maxReservedUsd = Precision.applyFactor(poolUsd, reserveFactor);

        uint256 reservedUsd = getReservedUsd(
            dataStore,
            market,
            prices,
            isLong
        );

        if (reservedUsd > maxReservedUsd) {
            revert Errors.InsufficientReserve(reservedUsd, maxReservedUsd);
        }
    }

    // @dev validate that the amount of tokens required to be reserved for open interest
    // is below the configured threshold
    // @param dataStore DataStore
    // @param market the market values
    // @param prices the prices of the market tokens
    // @param isLong whether to check the long or short side
    function validateOpenInterestReserve(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) internal view {
        // poolUsd is used instead of pool amount as the indexToken may not match the longToken
        // additionally, the shortToken may not be a stablecoin
        uint256 poolUsd = getPoolUsdWithoutPnl(dataStore, market, prices, isLong, false);
        uint256 reserveFactor = getOpenInterestReserveFactor(dataStore, market.marketToken, isLong);
        uint256 maxReservedUsd = Precision.applyFactor(poolUsd, reserveFactor);

        uint256 reservedUsd = getReservedUsd(
            dataStore,
            market,
            prices,
            isLong
        );

        if (reservedUsd > maxReservedUsd) {
            revert Errors.InsufficientReserveForOpenInterest(reservedUsd, maxReservedUsd);
        }
    }

    // @dev update the swap impact pool amount, if it is a positive impact amount
    // cap the impact amount to the amount available in the swap impact pool
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to apply to
    // @param token the token to apply to
    // @param tokenPrice the price of the token
    // @param priceImpactUsd the USD price impact
    function applySwapImpactWithCap(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address token,
        Price.Props memory tokenPrice,
        int256 priceImpactUsd
    ) internal returns (int256, uint256) {
        (int256 impactAmount, uint256 cappedDiffUsd) = getSwapImpactAmountWithCap(
            dataStore,
            market,
            token,
            tokenPrice,
            priceImpactUsd
        );

        // if there is a positive impact, the impact pool amount should be reduced
        // if there is a negative impact, the impact pool amount should be increased
        applyDeltaToSwapImpactPool(
            dataStore,
            eventEmitter,
            market,
            token,
            -impactAmount
        );

        return (impactAmount, cappedDiffUsd);
    }

    function getSwapImpactAmountWithCap(
        DataStore dataStore,
        address market,
        address token,
        Price.Props memory tokenPrice,
        int256 priceImpactUsd
    ) internal view returns (int256, uint256) {
        int256 impactAmount;
        uint256 cappedDiffUsd;

        if (priceImpactUsd > 0) {
            // positive impact: minimize impactAmount, use tokenPrice.max
            // round positive impactAmount down, this will be deducted from the swap impact pool for the user
            impactAmount = priceImpactUsd / tokenPrice.max.toInt256();

            int256 maxImpactAmount = getSwapImpactPoolAmount(dataStore, market, token).toInt256();
            if (impactAmount > maxImpactAmount) {
                cappedDiffUsd = (impactAmount - maxImpactAmount).toUint256() * tokenPrice.max;
                impactAmount = maxImpactAmount;
            }
        } else {
            // negative impact: maximize impactAmount, use tokenPrice.min
            // round negative impactAmount up, this will be deducted from the user
            impactAmount = Calc.roundUpMagnitudeDivision(priceImpactUsd, tokenPrice.min);
        }

        return (impactAmount, cappedDiffUsd);
    }

    // @dev get the funding amount to be deducted or distributed
    //
    // @param latestFundingAmountPerSize the latest funding amount per size
    // @param positionFundingAmountPerSize the funding amount per size for the position
    // @param positionSizeInUsd the position size in USD
    // @param roundUpMagnitude whether the round up the result
    //
    // @return fundingAmount
    function getFundingAmount(
        uint256 latestFundingAmountPerSize,
        uint256 positionFundingAmountPerSize,
        uint256 positionSizeInUsd,
        bool roundUpMagnitude
    ) internal pure returns (uint256) {
        uint256 fundingDiffFactor = (latestFundingAmountPerSize - positionFundingAmountPerSize);

        // a user could avoid paying funding fees by continually updating the position
        // before the funding fee becomes large enough to be chargeable
        // to avoid this, funding fee amounts should be rounded up
        //
        // this could lead to large additional charges if the token has a low number of decimals
        // or if the token's value is very high, so care should be taken to inform users of this
        //
        // if the calculation is for the claimable amount, the amount should be rounded down instead

        // divide the result by Precision.FLOAT_PRECISION * Precision.FLOAT_PRECISION_SQRT as the fundingAmountPerSize values
        // are stored based on FLOAT_PRECISION_SQRT values
        return Precision.mulDiv(
            positionSizeInUsd,
            fundingDiffFactor,
            Precision.FLOAT_PRECISION * Precision.FLOAT_PRECISION_SQRT,
            roundUpMagnitude
        );
    }

    // @dev get the borrowing fees for a position, assumes that cumulativeBorrowingFactor
    // has already been updated to the latest value
    // @param dataStore DataStore
    // @param position Position.Props
    // @return the borrowing fees for a position
    function getBorrowingFees(DataStore dataStore, Position.Props memory position) internal view returns (uint256) {
        uint256 cumulativeBorrowingFactor = getCumulativeBorrowingFactor(dataStore, position.market(), position.isLong());
        if (position.borrowingFactor() > cumulativeBorrowingFactor) {
            revert Errors.UnexpectedBorrowingFactor(position.borrowingFactor(), cumulativeBorrowingFactor);
        }
        uint256 diffFactor = cumulativeBorrowingFactor - position.borrowingFactor();
        return Precision.applyFactor(position.sizeInUsd(), diffFactor);
    }

    // @dev get the borrowing fees for a position by calculating the latest cumulativeBorrowingFactor
    // @param dataStore DataStore
    // @param position Position.Props
    // @param market the position's market
    // @param prices the prices of the market tokens
    // @return the borrowing fees for a position
    function getNextBorrowingFees(DataStore dataStore, Position.Props memory position, Market.Props memory market, MarketPrices memory prices) internal view returns (uint256) {
        (uint256 nextCumulativeBorrowingFactor, /* uint256 delta */, ) = getNextCumulativeBorrowingFactor(
            dataStore,
            market,
            prices,
            position.isLong()
        );

        if (position.borrowingFactor() > nextCumulativeBorrowingFactor) {
            revert Errors.UnexpectedBorrowingFactor(position.borrowingFactor(), nextCumulativeBorrowingFactor);
        }
        uint256 diffFactor = nextCumulativeBorrowingFactor - position.borrowingFactor();
        return Precision.applyFactor(position.sizeInUsd(), diffFactor);
    }

    // @dev get the total reserved USD required for positions
    // @param market the market to check
    // @param prices the prices of the market tokens
    // @param isLong whether to get the value for the long or short side
    function getReservedUsd(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) internal view returns (uint256) {
        uint256 reservedUsd;
        if (isLong) {
            // for longs calculate the reserved USD based on the open interest and current indexTokenPrice
            // this works well for e.g. an ETH / USD market with long collateral token as WETH
            // the available amount to be reserved would scale with the price of ETH
            // this also works for e.g. a SOL / USD market with long collateral token as WETH
            // if the price of SOL increases more than the price of ETH, additional amounts would be
            // automatically reserved
            uint256 openInterestInTokens = getOpenInterestInTokens(dataStore, market, isLong);
            reservedUsd = openInterestInTokens * prices.indexTokenPrice.max;
        } else {
            // for shorts use the open interest as the reserved USD value
            // this works well for e.g. an ETH / USD market with short collateral token as USDC
            // the available amount to be reserved would not change with the price of ETH
            reservedUsd = getOpenInterest(dataStore, market, isLong);
        }

        return reservedUsd;
    }

    // @dev get the virtual inventory for swaps
    // @param dataStore DataStore
    // @param market the market to check
    // @return returns (has virtual inventory, virtual long token inventory, virtual short token inventory)
    function getVirtualInventoryForSwaps(DataStore dataStore, address market) internal view returns (bool, uint256, uint256) {
        bytes32 virtualMarketId = dataStore.getBytes32(Keys.virtualMarketIdKey(market));
        if (virtualMarketId == bytes32(0)) {
            return (false, 0, 0);
        }

        return (
            true,
            dataStore.getUint(Keys.virtualInventoryForSwapsKey(virtualMarketId, true)),
            dataStore.getUint(Keys.virtualInventoryForSwapsKey(virtualMarketId, false))
        );
    }

    function getIsLongToken(Market.Props memory market, address token) internal pure returns (bool) {
        if (token != market.longToken && token != market.shortToken) {
            revert Errors.UnexpectedTokenForVirtualInventory(token, market.marketToken);
        }

        return token == market.longToken;
    }

    // @dev get the virtual inventory for positions
    // @param dataStore DataStore
    // @param token the token to check
    function getVirtualInventoryForPositions(DataStore dataStore, address token) internal view returns (bool, int256) {
        bytes32 virtualTokenId = dataStore.getBytes32(Keys.virtualTokenIdKey(token));
        if (virtualTokenId == bytes32(0)) {
            return (false, 0);
        }

        return (true, dataStore.getInt(Keys.virtualInventoryForPositionsKey(virtualTokenId)));
    }

    // @dev update the virtual inventory for swaps
    // @param dataStore DataStore
    // @param marketAddress the market to update
    // @param token the token to update
    // @param delta the update amount
    function applyDeltaToVirtualInventoryForSwaps(
        DataStore dataStore,
        EventEmitter eventEmitter,
        Market.Props memory market,
        address token,
        int256 delta
    ) internal returns (bool, uint256) {
        bytes32 virtualMarketId = dataStore.getBytes32(Keys.virtualMarketIdKey(market.marketToken));
        if (virtualMarketId == bytes32(0)) {
            return (false, 0);
        }

        bool isLongToken = getIsLongToken(market, token);

        uint256 nextValue = dataStore.applyBoundedDeltaToUint(
            Keys.virtualInventoryForSwapsKey(virtualMarketId, isLongToken),
            delta
        );

        MarketEventUtils.emitVirtualSwapInventoryUpdated(eventEmitter, market.marketToken, isLongToken, virtualMarketId, delta, nextValue);

        return (true, nextValue);
    }

    // @dev update the virtual inventory for positions
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param token the token to update
    // @param delta the update amount
    function applyDeltaToVirtualInventoryForPositions(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address token,
        int256 delta
    ) internal returns (bool, int256) {
        bytes32 virtualTokenId = dataStore.getBytes32(Keys.virtualTokenIdKey(token));
        if (virtualTokenId == bytes32(0)) {
            return (false, 0);
        }

        int256 nextValue = dataStore.applyDeltaToInt(
            Keys.virtualInventoryForPositionsKey(virtualTokenId),
            delta
        );

        MarketEventUtils.emitVirtualPositionInventoryUpdated(eventEmitter, token, virtualTokenId, delta, nextValue);

        return (true, nextValue);
    }

    // @dev get the open interest of a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    function getOpenInterest(
        DataStore dataStore,
        Market.Props memory market
    ) internal view returns (uint256) {
        uint256 longOpenInterest = getOpenInterest(dataStore, market, true);
        uint256 shortOpenInterest = getOpenInterest(dataStore, market, false);

        return longOpenInterest + shortOpenInterest;
    }

    // @dev get either the long or short open interest for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param isLong whether to get the long or short open interest
    // @return the long or short open interest for a market
    function getOpenInterest(
        DataStore dataStore,
        Market.Props memory market,
        bool isLong
    ) internal view returns (uint256) {
        uint256 divisor = getPoolDivisor(market.longToken, market.shortToken);
        uint256 openInterestUsingLongTokenAsCollateral = getOpenInterest(dataStore, market.marketToken, market.longToken, isLong, divisor);
        uint256 openInterestUsingShortTokenAsCollateral = getOpenInterest(dataStore, market.marketToken, market.shortToken, isLong, divisor);

        return openInterestUsingLongTokenAsCollateral + openInterestUsingShortTokenAsCollateral;
    }

    // @dev the long and short open interest for a market based on the collateral token used
    // @param dataStore DataStore
    // @param market the market to check
    // @param collateralToken the collateral token to check
    // @param isLong whether to check the long or short side
    function getOpenInterest(
        DataStore dataStore,
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return dataStore.getUint(Keys.openInterestKey(market, collateralToken, isLong)) / divisor;
    }

    // this is used to divide the values of getPoolAmount and getOpenInterest
    // if the longToken and shortToken are the same, then these values have to be divided by two
    // to avoid double counting
    function getPoolDivisor(address longToken, address shortToken) internal pure returns (uint256) {
        return longToken == shortToken ? 2 : 1;
    }

    // @dev the long and short open interest in tokens for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param isLong whether to check the long or short side
    function getOpenInterestInTokens(
        DataStore dataStore,
        Market.Props memory market,
        bool isLong
    ) internal view returns (uint256) {
        uint256 divisor = getPoolDivisor(market.longToken, market.shortToken);
        uint256 openInterestUsingLongTokenAsCollateral = getOpenInterestInTokens(dataStore, market.marketToken, market.longToken, isLong, divisor);
        uint256 openInterestUsingShortTokenAsCollateral = getOpenInterestInTokens(dataStore, market.marketToken, market.shortToken, isLong, divisor);

        return openInterestUsingLongTokenAsCollateral + openInterestUsingShortTokenAsCollateral;
    }

    // @dev the long and short open interest in tokens for a market based on the collateral token used
    // @param dataStore DataStore
    // @param market the market to check
    // @param collateralToken the collateral token to check
    // @param isLong whether to check the long or short side
    function getOpenInterestInTokens(
        DataStore dataStore,
        address market,
        address collateralToken,
        bool isLong,
        uint256 divisor
    ) internal view returns (uint256) {
        return dataStore.getUint(Keys.openInterestInTokensKey(market, collateralToken, isLong)) / divisor;
    }

    // @dev get the sum of open interest and pnl for a market
    // getOpenInterestInTokens * tokenPrice would not reflect pending positive pnl
    // for short positions, so getOpenInterestWithPnl should be used if that info is needed
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param indexTokenPrice the price of the index token
    // @param isLong whether to check the long or short side
    // @param maximize whether to maximize or minimize the value
    // @return the sum of open interest and pnl for a market
    function getOpenInterestWithPnl(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        bool isLong,
        bool maximize
    ) internal view returns (int256) {
        uint256 openInterest = getOpenInterest(dataStore, market, isLong);
        int256 pnl = getPnl(dataStore, market, indexTokenPrice, isLong, maximize);
        return Calc.sumReturnInt256(openInterest, pnl);
    }

    // @dev get the max position impact factor for decreasing position
    // @param dataStore DataStore
    // @param market the market to check
    // @param isPositive whether the price impact is positive or negative
    function getMaxPositionImpactFactor(DataStore dataStore, address market, bool isPositive) internal view returns (uint256) {
        (uint256 maxPositiveImpactFactor, uint256 maxNegativeImpactFactor) = getMaxPositionImpactFactors(dataStore, market);

        return isPositive ? maxPositiveImpactFactor : maxNegativeImpactFactor;
    }

    function getMaxPositionImpactFactors(DataStore dataStore, address market) internal view returns (uint256, uint256) {
        uint256 maxPositiveImpactFactor = dataStore.getUint(Keys.maxPositionImpactFactorKey(market, true));
        uint256 maxNegativeImpactFactor = dataStore.getUint(Keys.maxPositionImpactFactorKey(market, false));

        if (maxPositiveImpactFactor > maxNegativeImpactFactor) {
            maxPositiveImpactFactor = maxNegativeImpactFactor;
        }

        return (maxPositiveImpactFactor, maxNegativeImpactFactor);
    }

    // @dev get the max position impact factor for liquidations
    // @param dataStore DataStore
    // @param market the market to check
    function getMaxPositionImpactFactorForLiquidations(DataStore dataStore, address market) internal view returns (uint256) {
        return dataStore.getUint(Keys.maxPositionImpactFactorForLiquidationsKey(market));
    }

    // @dev get the min collateral factor
    // @param dataStore DataStore
    // @param market the market to check
    function getMinCollateralFactor(DataStore dataStore, address market) internal view returns (uint256) {
        return dataStore.getUint(Keys.minCollateralFactorKey(market));
    }

    // @dev get the min collateral factor for open interest multiplier
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether it is for the long or short side
    function getMinCollateralFactorForOpenInterestMultiplier(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.minCollateralFactorForOpenInterestMultiplierKey(market, isLong));
    }

    // @dev get the min collateral factor for open interest
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param openInterestDelta the change in open interest
    // @param isLong whether it is for the long or short side
    function getMinCollateralFactorForOpenInterest(
        DataStore dataStore,
        Market.Props memory market,
        int256 openInterestDelta,
        bool isLong
    ) internal view returns (uint256) {
        uint256 openInterest = getOpenInterest(dataStore, market, isLong);
        openInterest = Calc.sumReturnUint256(openInterest, openInterestDelta);
        uint256 multiplierFactor = getMinCollateralFactorForOpenInterestMultiplier(dataStore, market.marketToken, isLong);
        return Precision.applyFactor(openInterest, multiplierFactor);
    }

    // @dev get the total amount of position collateral for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to get the value for longs or shorts
    // @return the total amount of position collateral for a market
    function getCollateralSum(DataStore dataStore, address market, address collateralToken, bool isLong, uint256 divisor) internal view returns (uint256) {
        return dataStore.getUint(Keys.collateralSumKey(market, collateralToken, isLong)) / divisor;
    }

    // @dev get the reserve factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to get the value for longs or shorts
    // @return the reserve factor for a market
    function getReserveFactor(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.reserveFactorKey(market, isLong));
    }

    // @dev get the open interest reserve factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to get the value for longs or shorts
    // @return the open interest reserve factor for a market
    function getOpenInterestReserveFactor(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.openInterestReserveFactorKey(market, isLong));
    }

    // @dev get the max pnl factor for a market
    // @param dataStore DataStore
    // @param pnlFactorType the type of the pnl factor
    // @param market the market to check
    // @param isLong whether to get the value for longs or shorts
    // @return the max pnl factor for a market
    function getMaxPnlFactor(DataStore dataStore, bytes32 pnlFactorType, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.maxPnlFactorKey(pnlFactorType, market, isLong));
    }

    // @dev get the min pnl factor after ADL
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    function getMinPnlFactorAfterAdl(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.minPnlFactorAfterAdlKey(market, isLong));
    }

    // @dev get the funding factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @return the funding factor for a market
    function getFundingFactor(DataStore dataStore, address market) internal view returns (uint256) {
        return dataStore.getUint(Keys.fundingFactorKey(market));
    }

    // @dev get the saved funding factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @return the saved funding factor for a market
    function getSavedFundingFactorPerSecond(DataStore dataStore, address market) internal view returns (int256) {
        return dataStore.getInt(Keys.savedFundingFactorPerSecondKey(market));
    }

    // @dev set the saved funding factor
    // @param dataStore DataStore
    // @param market the market to set the funding factor for
    function setSavedFundingFactorPerSecond(DataStore dataStore, address market, int256 value) internal returns (int256) {
        return dataStore.setInt(Keys.savedFundingFactorPerSecondKey(market), value);
    }

    // @dev get the funding exponent factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @return the funding exponent factor for a market
    function getFundingExponentFactor(DataStore dataStore, address market) internal view returns (uint256) {
        return dataStore.getUint(Keys.fundingExponentFactorKey(market));
    }

    // @dev get the funding fee amount per size for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short size
    // @return the funding fee amount per size for a market based on collateralToken
    function getFundingFeeAmountPerSize(DataStore dataStore, address market, address collateralToken, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.fundingFeeAmountPerSizeKey(market, collateralToken, isLong));
    }

    // @dev get the claimable funding amount per size for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param collateralToken the collateralToken to check
    // @param isLong whether to check the long or short size
    // @return the claimable funding amount per size for a market based on collateralToken
    function getClaimableFundingAmountPerSize(DataStore dataStore, address market, address collateralToken, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.claimableFundingAmountPerSizeKey(market, collateralToken, isLong));
    }

    // @dev apply delta to the funding fee amount per size for a market
    // @param dataStore DataStore
    // @param market the market to set
    // @param collateralToken the collateralToken to set
    // @param isLong whether to set it for the long or short side
    // @param delta the delta to increment by
    function applyDeltaToFundingFeeAmountPerSize(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        uint256 delta
    ) internal {
        if (delta == 0) { return; }

        uint256 nextValue = dataStore.applyDeltaToUint(
            Keys.fundingFeeAmountPerSizeKey(market, collateralToken, isLong),
            delta
        );

        MarketEventUtils.emitFundingFeeAmountPerSizeUpdated(
            eventEmitter,
            market,
            collateralToken,
            isLong,
            delta,
            nextValue
        );
    }

    // @dev apply delta to the claimable funding amount per size for a market
    // @param dataStore DataStore
    // @param market the market to set
    // @param collateralToken the collateralToken to set
    // @param isLong whether to set it for the long or short side
    // @param delta the delta to increment by
    function applyDeltaToClaimableFundingAmountPerSize(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        address collateralToken,
        bool isLong,
        uint256 delta
    ) internal {
        if (delta == 0) { return; }

        uint256 nextValue = dataStore.applyDeltaToUint(
            Keys.claimableFundingAmountPerSizeKey(market, collateralToken, isLong),
            delta
        );

        MarketEventUtils.emitClaimableFundingAmountPerSizeUpdated(
            eventEmitter,
            market,
            collateralToken,
            isLong,
            delta,
            nextValue
        );
    }

    // @dev get the number of seconds since funding was updated for a market
    // @param market the market to check
    // @return the number of seconds since funding was updated for a market
    function getSecondsSinceFundingUpdated(DataStore dataStore, address market) internal view returns (uint256) {
        uint256 updatedAt = dataStore.getUint(Keys.fundingUpdatedAtKey(market));
        if (updatedAt == 0) { return 0; }
        return Chain.currentTimestamp() - updatedAt;
    }

    // @dev get the borrowing factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @return the borrowing factor for a market
    function getBorrowingFactor(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.borrowingFactorKey(market, isLong));
    }

    function getOptimalUsageFactor(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.optimalUsageFactorKey(market, isLong));
    }

    // @dev get the borrowing exponent factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @return the borrowing exponent factor for a market
    function getBorrowingExponentFactor(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.borrowingExponentFactorKey(market, isLong));
    }

    // @dev get the cumulative borrowing factor for a market
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @return the cumulative borrowing factor for a market
    function getCumulativeBorrowingFactor(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.cumulativeBorrowingFactorKey(market, isLong));
    }

    // @dev increase the cumulative borrowing factor
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param market the market to increment the borrowing factor for
    // @param isLong whether to increment the long or short side
    // @param delta the increase amount
    function incrementCumulativeBorrowingFactor(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market,
        bool isLong,
        uint256 delta
    ) internal {
        uint256 nextCumulativeBorrowingFactor = dataStore.incrementUint(
            Keys.cumulativeBorrowingFactorKey(market, isLong),
            delta
        );

        MarketEventUtils.emitBorrowingFactorUpdated(
            eventEmitter,
            market,
            isLong,
            delta,
            nextCumulativeBorrowingFactor
        );
    }

    // @dev get the timestamp of when the cumulative borrowing factor was last updated
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @return the timestamp of when the cumulative borrowing factor was last updated
    function getCumulativeBorrowingFactorUpdatedAt(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.cumulativeBorrowingFactorUpdatedAtKey(market, isLong));
    }

    // @dev get the number of seconds since the cumulative borrowing factor was last updated
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @return the number of seconds since the cumulative borrowing factor was last updated
    function getSecondsSinceCumulativeBorrowingFactorUpdated(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        uint256 updatedAt = getCumulativeBorrowingFactorUpdatedAt(dataStore, market, isLong);
        if (updatedAt == 0) { return 0; }
        return Chain.currentTimestamp() - updatedAt;
    }

    // @dev update the total borrowing amount after a position changes size
    // this is the sum of all position.borrowingFactor * position.sizeInUsd
    // @param dataStore DataStore
    // @param market the market to update
    // @param isLong whether to update the long or short side
    // @param prevPositionSizeInUsd the previous position size in USD
    // @param prevPositionBorrowingFactor the previous position borrowing factor
    // @param nextPositionSizeInUsd the next position size in USD
    // @param nextPositionBorrowingFactor the next position borrowing factor
    function updateTotalBorrowing(
        DataStore dataStore,
        address market,
        bool isLong,
        uint256 prevPositionSizeInUsd,
        uint256 prevPositionBorrowingFactor,
        uint256 nextPositionSizeInUsd,
        uint256 nextPositionBorrowingFactor
    ) external {
        uint256 totalBorrowing = getNextTotalBorrowing(
            dataStore,
            market,
            isLong,
            prevPositionSizeInUsd,
            prevPositionBorrowingFactor,
            nextPositionSizeInUsd,
            nextPositionBorrowingFactor
        );

        setTotalBorrowing(dataStore, market, isLong, totalBorrowing);
    }

    // @dev get the next total borrowing amount after a position changes size
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @param prevPositionSizeInUsd the previous position size in USD
    // @param prevPositionBorrowingFactor the previous position borrowing factor
    // @param nextPositionSizeInUsd the next position size in USD
    // @param nextPositionBorrowingFactor the next position borrowing factor
    function getNextTotalBorrowing(
        DataStore dataStore,
        address market,
        bool isLong,
        uint256 prevPositionSizeInUsd,
        uint256 prevPositionBorrowingFactor,
        uint256 nextPositionSizeInUsd,
        uint256 nextPositionBorrowingFactor
    ) internal view returns (uint256) {
        uint256 totalBorrowing = getTotalBorrowing(dataStore, market, isLong);
        totalBorrowing -= Precision.applyFactor(prevPositionSizeInUsd, prevPositionBorrowingFactor);
        totalBorrowing += Precision.applyFactor(nextPositionSizeInUsd, nextPositionBorrowingFactor);

        return totalBorrowing;
    }

    // @dev get the next cumulative borrowing factor
    // @param dataStore DataStore
    // @param prices the prices of the market tokens
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param isLong whether to check the long or short side
    function getNextCumulativeBorrowingFactor(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) internal view returns (uint256, uint256, uint256) {
        uint256 durationInSeconds = getSecondsSinceCumulativeBorrowingFactorUpdated(dataStore, market.marketToken, isLong);
        uint256 borrowingFactorPerSecond = getBorrowingFactorPerSecond(
            dataStore,
            market,
            prices,
            isLong
        );

        uint256 cumulativeBorrowingFactor = getCumulativeBorrowingFactor(dataStore, market.marketToken, isLong);

        uint256 delta = durationInSeconds * borrowingFactorPerSecond;
        uint256 nextCumulativeBorrowingFactor = cumulativeBorrowingFactor + delta;
        return (nextCumulativeBorrowingFactor, delta, borrowingFactorPerSecond);
    }

    // @dev get the borrowing factor per second
    // @param dataStore DataStore
    // @param market the market to get the borrowing factor per second for
    // @param prices the prices of the market tokens
    // @param isLong whether to get the factor for the long or short side
    function getBorrowingFactorPerSecond(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) internal view returns (uint256) {
        uint256 reservedUsd = getReservedUsd(
            dataStore,
            market,
            prices,
            isLong
        );

        if (reservedUsd == 0) { return 0; }

        // check if the borrowing fee for the smaller side should be skipped
        // if skipBorrowingFeeForSmallerSide is true, and the longOpenInterest is exactly the same as the shortOpenInterest
        // then the borrowing fee would be charged for both sides, this should be very rare
        bool skipBorrowingFeeForSmallerSide = dataStore.getBool(Keys.SKIP_BORROWING_FEE_FOR_SMALLER_SIDE);
        if (skipBorrowingFeeForSmallerSide) {
            uint256 longOpenInterest = getOpenInterest(dataStore, market, true);
            uint256 shortOpenInterest = getOpenInterest(dataStore, market, false);

            // if getting the borrowing factor for longs and if the longOpenInterest
            // is smaller than the shortOpenInterest, then return zero
            if (isLong && longOpenInterest < shortOpenInterest) {
                return 0;
            }

            // if getting the borrowing factor for shorts and if the shortOpenInterest
            // is smaller than the longOpenInterest, then return zero
            if (!isLong && shortOpenInterest < longOpenInterest) {
                return 0;
            }
        }

        uint256 poolUsd = getPoolUsdWithoutPnl(dataStore, market, prices, isLong, false);

        if (poolUsd == 0) {
            revert Errors.UnableToGetBorrowingFactorEmptyPoolUsd();
        }

        uint256 optimalUsageFactor = getOptimalUsageFactor(dataStore, market.marketToken, isLong);

        if (optimalUsageFactor != 0) {
            return getKinkBorrowingFactor(
                dataStore,
                market,
                isLong,
                reservedUsd,
                poolUsd,
                optimalUsageFactor
            );
        }

        uint256 borrowingExponentFactor = getBorrowingExponentFactor(dataStore, market.marketToken, isLong);
        uint256 reservedUsdAfterExponent = Precision.applyExponentFactor(reservedUsd, borrowingExponentFactor);

        uint256 reservedUsdToPoolFactor = Precision.toFactor(reservedUsdAfterExponent, poolUsd);
        uint256 borrowingFactor = getBorrowingFactor(dataStore, market.marketToken, isLong);

        return Precision.applyFactor(reservedUsdToPoolFactor, borrowingFactor);
    }

    function getKinkBorrowingFactor(
        DataStore dataStore,
        Market.Props memory market,
        bool isLong,
        uint256 reservedUsd,
        uint256 poolUsd,
        uint256 optimalUsageFactor
    ) internal view returns (uint256) {
        uint256 usageFactor = getUsageFactor(
            dataStore,
            market,
            isLong,
            reservedUsd,
            poolUsd
        );

        uint256 baseBorrowingFactor = dataStore.getUint(Keys.baseBorrowingFactorKey(market.marketToken, isLong));

        uint256 borrowingFactorPerSecond = Precision.applyFactor(
            usageFactor,
            baseBorrowingFactor
        );

        if (usageFactor > optimalUsageFactor && Precision.FLOAT_PRECISION > optimalUsageFactor) {
            uint256 diff = usageFactor - optimalUsageFactor;

            uint256 aboveOptimalUsageBorrowingFactor = dataStore.getUint(Keys.aboveOptimalUsageBorrowingFactorKey(market.marketToken, isLong));
            uint256 additionalBorrowingFactorPerSecond;

            if (aboveOptimalUsageBorrowingFactor > baseBorrowingFactor) {
                additionalBorrowingFactorPerSecond = aboveOptimalUsageBorrowingFactor - baseBorrowingFactor;
            }

            uint256 divisor = Precision.FLOAT_PRECISION - optimalUsageFactor;

            borrowingFactorPerSecond += additionalBorrowingFactorPerSecond * diff / divisor;
        }

        return borrowingFactorPerSecond;
    }

    function distributePositionImpactPool(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address market
    ) external {
        (uint256 distributionAmount, uint256 nextPositionImpactPoolAmount) = getPendingPositionImpactPoolDistributionAmount(dataStore, market);

        if (distributionAmount != 0) {
            applyDeltaToPositionImpactPool(
                dataStore,
                eventEmitter,
                market,
                -distributionAmount.toInt256()
            );

            MarketEventUtils.emitPositionImpactPoolDistributed(
                eventEmitter,
                market,
                distributionAmount,
                nextPositionImpactPoolAmount
            );
        }

        dataStore.setUint(Keys.positionImpactPoolDistributedAtKey(market), Chain.currentTimestamp());
    }

    function getNextPositionImpactPoolAmount(
        DataStore dataStore,
        address market
    ) internal view returns (uint256) {
        (/* uint256 distributionAmount */, uint256 nextPositionImpactPoolAmount) = getPendingPositionImpactPoolDistributionAmount(dataStore, market);

        return nextPositionImpactPoolAmount;
    }

    // @return (distributionAmount, nextPositionImpactPoolAmount)
    function getPendingPositionImpactPoolDistributionAmount(
        DataStore dataStore,
        address market
    ) internal view returns (uint256, uint256) {
        uint256 positionImpactPoolAmount = getPositionImpactPoolAmount(dataStore, market);
        if (positionImpactPoolAmount == 0) { return (0, positionImpactPoolAmount); }

        uint256 distributionRate = dataStore.getUint(Keys.positionImpactPoolDistributionRateKey(market));
        if (distributionRate == 0) { return (0, positionImpactPoolAmount); }

        uint256 minPositionImpactPoolAmount = dataStore.getUint(Keys.minPositionImpactPoolAmountKey(market));
        if (positionImpactPoolAmount <= minPositionImpactPoolAmount) { return (0, positionImpactPoolAmount); }

        uint256 maxDistributionAmount = positionImpactPoolAmount - minPositionImpactPoolAmount;

        uint256 durationInSeconds = getSecondsSincePositionImpactPoolDistributed(dataStore, market);
        uint256 distributionAmount = Precision.applyFactor(durationInSeconds, distributionRate);

        if (distributionAmount > maxDistributionAmount) {
            distributionAmount = maxDistributionAmount;
        }

        return (distributionAmount, positionImpactPoolAmount - distributionAmount);
    }

    function getSecondsSincePositionImpactPoolDistributed(
        DataStore dataStore,
        address market
    ) internal view returns (uint256) {
        uint256 distributedAt = dataStore.getUint(Keys.positionImpactPoolDistributedAtKey(market));
        if (distributedAt == 0) { return 0; }
        return Chain.currentTimestamp() - distributedAt;
    }

    // @dev get the total pending borrowing fees
    // @param dataStore DataStore
    // @param market the market to check
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param isLong whether to check the long or short side
    function getTotalPendingBorrowingFees(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong
    ) internal view returns (uint256) {
        uint256 openInterest = getOpenInterest(
            dataStore,
            market,
            isLong
        );

        (uint256 nextCumulativeBorrowingFactor, /* uint256 delta */, ) = getNextCumulativeBorrowingFactor(
            dataStore,
            market,
            prices,
            isLong
        );

        uint256 totalBorrowing = getTotalBorrowing(dataStore, market.marketToken, isLong);

        return Precision.applyFactor(openInterest, nextCumulativeBorrowingFactor) - totalBorrowing;
    }

    // @dev get the total borrowing value
    // the total borrowing value is the sum of position.borrowingFactor * position.size / (10 ^ 30)
    // for all positions of the market
    // if borrowing APR is 1000% for 100 years, the cumulativeBorrowingFactor could be as high as 100 * 10 * (10 ** 30)
    // (100% is 10 ** 30 so 1000% is 10 * (10 ** 30))
    // since position.size is a USD value with 30 decimals, under this scenario, there may be overflow issues
    // if open interest exceeds (2 ** 256) / (10 ** 30) / (100 * 10 * (10 ** 30)) => 115,792,090,000,000 USD
    // @param dataStore DataStore
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @return the total borrowing value
    function getTotalBorrowing(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.totalBorrowingKey(market, isLong));
    }

    // @dev set the total borrowing value
    // @param dataStore DataStore
    // @param market the market to set
    // @param isLong whether to set the long or short side
    // @param value the value to set to
    function setTotalBorrowing(DataStore dataStore, address market, bool isLong, uint256 value) internal returns (uint256) {
        return dataStore.setUint(Keys.totalBorrowingKey(market, isLong), value);
    }

    // @dev convert a USD value to number of market tokens
    // @param usdValue the input USD value
    // @param poolValue the value of the pool
    // @param supply the supply of market tokens
    // @return the number of market tokens
    function usdToMarketTokenAmount(
        uint256 usdValue,
        uint256 poolValue,
        uint256 supply
    ) internal pure returns (uint256) {
        // if the supply and poolValue is zero, use 1 USD as the token price
        if (supply == 0 && poolValue == 0) {
            return Precision.floatToWei(usdValue);
        }

        // if the supply is zero and the poolValue is more than zero,
        // then include the poolValue for the amount of tokens minted so that
        // the market token price after mint would be 1 USD
        if (supply == 0 && poolValue > 0) {
            return Precision.floatToWei(poolValue + usdValue);
        }

        // round market tokens down
        return Precision.mulDiv(supply, usdValue, poolValue);
    }

    // @dev convert a number of market tokens to its USD value
    // @param marketTokenAmount the input number of market tokens
    // @param poolValue the value of the pool
    // @param supply the supply of market tokens
    // @return the USD value of the market tokens
    function marketTokenAmountToUsd(
        uint256 marketTokenAmount,
        uint256 poolValue,
        uint256 supply
    ) internal pure returns (uint256) {
        if (supply == 0) { revert Errors.EmptyMarketTokenSupply(); }

        return Precision.mulDiv(poolValue, marketTokenAmount, supply);
    }

    // @dev validate that the specified market exists and is enabled
    // @param dataStore DataStore
    // @param marketAddress the address of the market
    function validateEnabledMarket(DataStore dataStore, address marketAddress) internal view {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateEnabledMarket(dataStore, market);
    }

    // @dev validate that the specified market exists and is enabled
    // @param dataStore DataStore
    // @param market the market to check
    function validateEnabledMarket(DataStore dataStore, Market.Props memory market) internal view {
        if (market.marketToken == address(0)) {
            revert Errors.EmptyMarket();
        }

        bool isMarketDisabled = dataStore.getBool(Keys.isMarketDisabledKey(market.marketToken));
        if (isMarketDisabled) {
            revert Errors.DisabledMarket(market.marketToken);
        }
    }

    // @dev validate that the positions can be opened in the given market
    // @param market the market to check
    function validatePositionMarket(DataStore dataStore, Market.Props memory market) internal view {
        validateEnabledMarket(dataStore, market);

        if (isSwapOnlyMarket(market)) {
            revert Errors.InvalidPositionMarket(market.marketToken);
        }
    }

    function validatePositionMarket(DataStore dataStore, address marketAddress) internal view {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validatePositionMarket(dataStore, market);
    }

    // @dev check if a market only supports swaps and not positions
    // @param market the market to check
    function isSwapOnlyMarket(Market.Props memory market) internal pure returns (bool) {
        return market.indexToken == address(0);
    }

    // @dev check if the given token is a collateral token of the market
    // @param market the market to check
    // @param token the token to check
    function isMarketCollateralToken(Market.Props memory market, address token) internal pure returns (bool) {
        return token == market.longToken || token == market.shortToken;
    }

    // @dev validate if the given token is a collateral token of the market
    // @param market the market to check
    // @param token the token to check
    function validateMarketCollateralToken(Market.Props memory market, address token) internal pure {
        if (!isMarketCollateralToken(market, token)) {
            revert Errors.InvalidCollateralTokenForMarket(market.marketToken, token);
        }
    }

    // @dev get the enabled market, revert if the market does not exist or is not enabled
    // @param dataStore DataStore
    // @param marketAddress the address of the market
    function getEnabledMarket(DataStore dataStore, address marketAddress) internal view returns (Market.Props memory) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateEnabledMarket(dataStore, market);
        return market;
    }

    function getSwapPathMarket(DataStore dataStore, address marketAddress) internal view returns (Market.Props memory) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        validateSwapMarket(dataStore, market);
        return market;
    }

    // @dev get a list of market values based on an input array of market addresses
    // @param swapPath list of market addresses
    function getSwapPathMarkets(DataStore dataStore, address[] memory swapPath) internal view returns (Market.Props[] memory) {
        Market.Props[] memory markets = new Market.Props[](swapPath.length);

        for (uint256 i; i < swapPath.length; i++) {
            address marketAddress = swapPath[i];
            markets[i] = getSwapPathMarket(dataStore, marketAddress);
        }

        return markets;
    }

    function validateSwapPath(DataStore dataStore, address[] memory swapPath) internal view {
        uint256 maxSwapPathLength = dataStore.getUint(Keys.MAX_SWAP_PATH_LENGTH);
        if (swapPath.length > maxSwapPathLength) {
            revert Errors.MaxSwapPathLengthExceeded(swapPath.length, maxSwapPathLength);
        }

        for (uint256 i; i < swapPath.length; i++) {
            address marketAddress = swapPath[i];
            validateSwapMarket(dataStore, marketAddress);
        }
    }

    // @dev validate that the pending pnl is below the allowed amount
    // @param dataStore DataStore
    // @param market the market to check
    // @param prices the prices of the market tokens
    // @param pnlFactorType the pnl factor type to check
    function validateMaxPnl(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bytes32 pnlFactorTypeForLongs,
        bytes32 pnlFactorTypeForShorts
    ) internal view {
        (bool isPnlFactorExceededForLongs, int256 pnlToPoolFactorForLongs, uint256 maxPnlFactorForLongs) = isPnlFactorExceeded(
            dataStore,
            market,
            prices,
            true,
            pnlFactorTypeForLongs
        );

        if (isPnlFactorExceededForLongs) {
            revert Errors.PnlFactorExceededForLongs(pnlToPoolFactorForLongs, maxPnlFactorForLongs);
        }

        (bool isPnlFactorExceededForShorts, int256 pnlToPoolFactorForShorts, uint256 maxPnlFactorForShorts) = isPnlFactorExceeded(
            dataStore,
            market,
            prices,
            false,
            pnlFactorTypeForShorts
        );

        if (isPnlFactorExceededForShorts) {
            revert Errors.PnlFactorExceededForShorts(pnlToPoolFactorForShorts, maxPnlFactorForShorts);
        }
    }

    // @dev check if the pending pnl exceeds the allowed amount
    // @param dataStore DataStore
    // @param oracle Oracle
    // @param market the market to check
    // @param isLong whether to check the long or short side
    // @param pnlFactorType the pnl factor type to check
    function isPnlFactorExceeded(
        DataStore dataStore,
        Oracle oracle,
        address market,
        bool isLong,
        bytes32 pnlFactorType
    ) internal view returns (bool, int256, uint256) {
        Market.Props memory _market = getEnabledMarket(dataStore, market);
        MarketPrices memory prices = getMarketPrices(oracle, _market);

        return isPnlFactorExceeded(
            dataStore,
            _market,
            prices,
            isLong,
            pnlFactorType
        );
    }

    // @dev check if the pending pnl exceeds the allowed amount
    // @param dataStore DataStore
    // @param _market the market to check
    // @param prices the prices of the market tokens
    // @param isLong whether to check the long or short side
    // @param pnlFactorType the pnl factor type to check
    function isPnlFactorExceeded(
        DataStore dataStore,
        Market.Props memory market,
        MarketPrices memory prices,
        bool isLong,
        bytes32 pnlFactorType
    ) internal view returns (bool, int256, uint256) {
        int256 pnlToPoolFactor = getPnlToPoolFactor(dataStore, market, prices, isLong, true);
        uint256 maxPnlFactor = getMaxPnlFactor(dataStore, pnlFactorType, market.marketToken, isLong);

        bool isExceeded = pnlToPoolFactor > 0 && pnlToPoolFactor.toUint256() > maxPnlFactor;

        return (isExceeded, pnlToPoolFactor, maxPnlFactor);
    }

    function getUiFeeFactor(DataStore dataStore, address account) internal view returns (uint256) {
        uint256 maxUiFeeFactor = dataStore.getUint(Keys.MAX_UI_FEE_FACTOR);
        uint256 uiFeeFactor = dataStore.getUint(Keys.uiFeeFactorKey(account));

        return uiFeeFactor < maxUiFeeFactor ? uiFeeFactor : maxUiFeeFactor;
    }

    function setUiFeeFactor(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address account,
        uint256 uiFeeFactor
    ) internal {
        uint256 maxUiFeeFactor = dataStore.getUint(Keys.MAX_UI_FEE_FACTOR);

        if (uiFeeFactor > maxUiFeeFactor) {
            revert Errors.InvalidUiFeeFactor(uiFeeFactor, maxUiFeeFactor);
        }

        dataStore.setUint(
            Keys.uiFeeFactorKey(account),
            uiFeeFactor
        );

        MarketEventUtils.emitUiFeeFactorUpdated(eventEmitter, account, uiFeeFactor);
    }

    function validateMarketTokenBalance(
        DataStore dataStore,
        Market.Props[] memory markets
    ) public view {
        for (uint256 i; i < markets.length; i++) {
            validateMarketTokenBalance(dataStore, markets[i]);
        }
    }

    function validateMarketTokenBalance(
        DataStore dataStore,
        address _market
    ) public view {
        Market.Props memory market = getEnabledMarket(dataStore, _market);
        validateMarketTokenBalance(dataStore, market);
    }

    function validateMarketTokenBalance(
        DataStore dataStore,
        Market.Props memory market
    ) public view {
        validateMarketTokenBalance(dataStore, market, market.longToken);

        if (market.longToken == market.shortToken) {
            return;
        }

        validateMarketTokenBalance(dataStore, market, market.shortToken);
    }

    function validateMarketTokenBalance(
        DataStore dataStore,
        Market.Props memory market,
        address token
    ) internal view {
        if (market.marketToken == address(0) || token == address(0)) {
            revert Errors.EmptyAddressInMarketTokenBalanceValidation(market.marketToken, token);
        }

        uint256 balance = IERC20(token).balanceOf(market.marketToken);
        uint256 expectedMinBalance = getExpectedMinTokenBalance(dataStore, market, token);

        if (balance < expectedMinBalance) {
            revert Errors.InvalidMarketTokenBalance(market.marketToken, token, balance, expectedMinBalance);
        }

        // funding fees can be claimed even if the collateral for positions that should pay funding fees
        // hasn't been reduced yet
        // due to that, funding fees and collateral is excluded from the expectedMinBalance calculation
        // and validated separately

        // use 1 for the getCollateralSum divisor since getCollateralSum does not sum over both the
        // longToken and shortToken
        uint256 collateralAmount = getCollateralSum(dataStore, market.marketToken, token, true, 1);
        collateralAmount += getCollateralSum(dataStore, market.marketToken, token, false, 1);

        if (balance < collateralAmount) {
            revert Errors.InvalidMarketTokenBalanceForCollateralAmount(market.marketToken, token, balance, collateralAmount);
        }

        uint256 claimableFundingFeeAmount = dataStore.getUint(Keys.claimableFundingAmountKey(market.marketToken, token));

        // in case of late liquidations, it may be possible for the claimableFundingFeeAmount to exceed the market token balance
        // but this should be very rare
        if (balance < claimableFundingFeeAmount) {
            revert Errors.InvalidMarketTokenBalanceForClaimableFunding(market.marketToken, token, balance, claimableFundingFeeAmount);
        }
    }

    function getExpectedMinTokenBalance(
        DataStore dataStore,
        Market.Props memory market,
        address token
    ) internal view returns (uint256) {
        GetExpectedMinTokenBalanceCache memory cache;

        // get the pool amount directly as MarketUtils.getPoolAmount will divide the amount by 2
        // for markets with the same long and short token
        cache.poolAmount = dataStore.getUint(Keys.poolAmountKey(market.marketToken, token));
        cache.swapImpactPoolAmount = getSwapImpactPoolAmount(dataStore, market.marketToken, token);
        cache.claimableCollateralAmount = dataStore.getUint(Keys.claimableCollateralAmountKey(market.marketToken, token));
        cache.claimableFeeAmount = dataStore.getUint(Keys.claimableFeeAmountKey(market.marketToken, token));
        cache.claimableUiFeeAmount = dataStore.getUint(Keys.claimableUiFeeAmountKey(market.marketToken, token));
        cache.affiliateRewardAmount = dataStore.getUint(Keys.affiliateRewardKey(market.marketToken, token));

        // funding fees are excluded from this summation as claimable funding fees
        // are incremented without a corresponding decrease of the collateral of
        // other positions, the collateral of other positions is decreased when
        // those positions are updated
        return
            cache.poolAmount
            + cache.swapImpactPoolAmount
            + cache.claimableCollateralAmount
            + cache.claimableFeeAmount
            + cache.claimableUiFeeAmount
            + cache.affiliateRewardAmount;
    }
}
