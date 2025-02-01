// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "../market/MarketUtils.sol";

import "../utils/Precision.sol";
import "../utils/Calc.sol";

import "./PricingUtils.sol";

import "../referral/IReferralStorage.sol";
import "../referral/ReferralUtils.sol";

// @title PositionPricingUtils
// @dev Library for position pricing functions
library PositionPricingUtils {
    using SignedMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Position for Position.Props;
    using Price for Price.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    struct GetPositionFeesParams {
        DataStore dataStore;
        IReferralStorage referralStorage;
        Position.Props position;
        Price.Props collateralTokenPrice;
        bool balanceWasImproved;
        address longToken;
        address shortToken;
        uint256 sizeDeltaUsd;
        address uiFeeReceiver;
        bool isLiquidation;
    }

    // @dev GetPriceImpactUsdParams struct used in getPriceImpactUsd to avoid stack
    // too deep errors
    // @param dataStore DataStore
    // @param market the market to check
    // @param usdDelta the change in position size in USD
    // @param isLong whether the position is long or short
    struct GetPriceImpactUsdParams {
        DataStore dataStore;
        Market.Props market;
        int256 usdDelta;
        bool isLong;
    }

    // @dev OpenInterestParams struct to contain open interest values
    // @param longOpenInterest the amount of long open interest
    // @param shortOpenInterest the amount of short open interest
    // @param nextLongOpenInterest the updated amount of long open interest
    // @param nextShortOpenInterest the updated amount of short open interest
    struct OpenInterestParams {
        uint256 longOpenInterest;
        uint256 shortOpenInterest;
        uint256 nextLongOpenInterest;
        uint256 nextShortOpenInterest;
    }

    // @dev PositionFees struct to contain fee values
    // @param feeReceiverAmount the amount for the fee receiver
    // @param feeAmountForPool the amount of fees for the pool
    // @param positionFeeAmountForPool the position fee amount for the pool
    // @param positionFeeAmount the fee amount for increasing / decreasing the position
    // @param borrowingFeeAmount the borrowing fee amount
    // @param totalCostAmount the total cost amount in tokens
    struct PositionFees {
        PositionReferralFees referral;
        PositionProFees pro;
        PositionFundingFees funding;
        PositionBorrowingFees borrowing;
        PositionUiFees ui;
        PositionLiquidationFees liquidation;
        Price.Props collateralTokenPrice;
        uint256 positionFeeFactor;
        uint256 protocolFeeAmount;
        uint256 positionFeeReceiverFactor;
        uint256 feeReceiverAmount;
        uint256 feeAmountForPool;
        uint256 positionFeeAmountForPool;
        uint256 positionFeeAmount;
        uint256 totalCostAmountExcludingFunding;
        uint256 totalCostAmount;
        uint256 totalDiscountAmount;
    }

    struct PositionProFees {
        uint256 traderTier;
        uint256 traderDiscountFactor;
        uint256 traderDiscountAmount;
    }

    struct PositionLiquidationFees {
        uint256 liquidationFeeUsd;
        uint256 liquidationFeeAmount;
        uint256 liquidationFeeReceiverFactor;
        uint256 liquidationFeeAmountForFeeReceiver;
    }

    // @param affiliate the referral affiliate of the trader
    // @param traderDiscountAmount the discount amount for the trader
    // @param affiliateRewardAmount the affiliate reward amount
    struct PositionReferralFees {
        bytes32 referralCode;
        address affiliate;
        address trader;
        uint256 totalRebateFactor;
        uint256 affiliateRewardFactor;
        uint256 adjustedAffiliateRewardFactor;
        uint256 traderDiscountFactor;
        uint256 totalRebateAmount;
        uint256 traderDiscountAmount;
        uint256 affiliateRewardAmount;
    }

    struct PositionBorrowingFees {
        uint256 borrowingFeeUsd;
        uint256 borrowingFeeAmount;
        uint256 borrowingFeeReceiverFactor;
        uint256 borrowingFeeAmountForFeeReceiver;
    }

    // @param fundingFeeAmount the position's funding fee amount
    // @param claimableLongTokenAmount the negative funding fee in long token that is claimable
    // @param claimableShortTokenAmount the negative funding fee in short token that is claimable
    // @param latestLongTokenFundingAmountPerSize the latest long token funding
    // amount per size for the market
    // @param latestShortTokenFundingAmountPerSize the latest short token funding
    // amount per size for the market
    struct PositionFundingFees {
        uint256 fundingFeeAmount;
        uint256 claimableLongTokenAmount;
        uint256 claimableShortTokenAmount;
        uint256 latestFundingFeeAmountPerSize;
        uint256 latestLongTokenClaimableFundingAmountPerSize;
        uint256 latestShortTokenClaimableFundingAmountPerSize;
    }

    struct PositionUiFees {
        address uiFeeReceiver;
        uint256 uiFeeReceiverFactor;
        uint256 uiFeeAmount;
    }

    // @dev get the price impact in USD for a position increase / decrease and whether the balance was improved
    // @param params GetPriceImpactUsdParams and the balanceWasImproved boolean
    function getPriceImpactUsd(GetPriceImpactUsdParams memory params) internal view returns (int256, bool) {
        OpenInterestParams memory openInterestParams = getNextOpenInterest(params);

        (int256 priceImpactUsd, bool balanceWasImproved) = _getPriceImpactUsd(params.dataStore, params.market.marketToken, openInterestParams);

        // the virtual price impact calculation is skipped if the price impact
        // is positive since the action is helping to balance the pool
        //
        // in case two virtual pools are unbalanced in a different direction
        // e.g. pool0 has more longs than shorts while pool1 has less longs
        // than shorts
        // not skipping the virtual price impact calculation would lead to
        // a negative price impact for any trade on either pools and would
        // disincentivise the balancing of pools
        if (priceImpactUsd >= 0) { return (priceImpactUsd, balanceWasImproved); }

        (bool hasVirtualInventory, int256 virtualInventory) = MarketUtils.getVirtualInventoryForPositions(params.dataStore, params.market.indexToken);
        if (!hasVirtualInventory) { return (priceImpactUsd, balanceWasImproved); }

        OpenInterestParams memory openInterestParamsForVirtualInventory = getNextOpenInterestForVirtualInventory(params, virtualInventory);
        (int256 priceImpactUsdForVirtualInventory, bool balanceWasImprovedForVirtualInventory) = _getPriceImpactUsd(params.dataStore, params.market.marketToken, openInterestParamsForVirtualInventory);

        return priceImpactUsdForVirtualInventory < priceImpactUsd ? (priceImpactUsdForVirtualInventory, balanceWasImprovedForVirtualInventory) : (priceImpactUsd, balanceWasImproved);
    }

    // @dev get the price impact in USD for a position increase / decrease and whether the balance was improved
    // @param dataStore DataStore
    // @param market the trading market
    // @param openInterestParams OpenInterestParams and the balanceWasImproved boolean
    function _getPriceImpactUsd(DataStore dataStore, address market, OpenInterestParams memory openInterestParams) internal view returns (int256, bool) {
        uint256 initialDiffUsd = Calc.diff(openInterestParams.longOpenInterest, openInterestParams.shortOpenInterest);
        uint256 nextDiffUsd = Calc.diff(openInterestParams.nextLongOpenInterest, openInterestParams.nextShortOpenInterest);

        // check whether an improvement in balance comes from causing the balance to switch sides
        // for example, if there is $2000 of ETH and $1000 of USDC in the pool
        // adding $1999 USDC into the pool will reduce absolute balance from $1000 to $999 but it does not
        // help rebalance the pool much, the isSameSideRebalance value helps avoid gaming using this case
        bool isSameSideRebalance = openInterestParams.longOpenInterest <= openInterestParams.shortOpenInterest == openInterestParams.nextLongOpenInterest <= openInterestParams.nextShortOpenInterest;
        uint256 impactExponentFactor = dataStore.getUint(Keys.positionImpactExponentFactorKey(market));

        bool balanceWasImproved = nextDiffUsd < initialDiffUsd;
        if (isSameSideRebalance) {
            uint256 impactFactor = MarketUtils.getAdjustedPositionImpactFactor(dataStore, market, balanceWasImproved);

            return (
                PricingUtils.getPriceImpactUsdForSameSideRebalance(
                    initialDiffUsd,
                    nextDiffUsd,
                    impactFactor,
                    impactExponentFactor
                ),
                balanceWasImproved
            );
        } else {
            (uint256 positiveImpactFactor, uint256 negativeImpactFactor) = MarketUtils.getAdjustedPositionImpactFactors(dataStore, market);

            return (
                PricingUtils.getPriceImpactUsdForCrossoverRebalance(
                    initialDiffUsd,
                    nextDiffUsd,
                    positiveImpactFactor,
                    negativeImpactFactor,
                    impactExponentFactor
                ),
                balanceWasImproved
            );
        }
    }

    // @dev get the next open interest values
    // @param params GetPriceImpactUsdParams
    // @return OpenInterestParams
    function getNextOpenInterest(
        GetPriceImpactUsdParams memory params
    ) internal view returns (OpenInterestParams memory) {
        uint256 longOpenInterest = MarketUtils.getOpenInterest(
            params.dataStore,
            params.market,
            true
        );

        uint256 shortOpenInterest = MarketUtils.getOpenInterest(
            params.dataStore,
            params.market,
            false
        );

        return getNextOpenInterestParams(params, longOpenInterest, shortOpenInterest);
    }

    function getNextOpenInterestForVirtualInventory(
        GetPriceImpactUsdParams memory params,
        int256 virtualInventory
    ) internal pure returns (OpenInterestParams memory) {
        uint256 longOpenInterest;
        uint256 shortOpenInterest;

        // if virtualInventory is more than zero it means that
        // tokens were virtually sold to the pool, so set shortOpenInterest
        // to the virtualInventory value
        // if virtualInventory is less than zero it means that
        // tokens were virtually bought from the pool, so set longOpenInterest
        // to the virtualInventory value
        if (virtualInventory > 0) {
            shortOpenInterest = virtualInventory.toUint256();
        } else {
            longOpenInterest = (-virtualInventory).toUint256();
        }

        // the virtual long and short open interest is adjusted by the usdDelta
        // to prevent an underflow in getNextOpenInterestParams
        // price impact depends on the change in USD balance, so offsetting both
        // values equally should not change the price impact calculation
        if (params.usdDelta < 0) {
            uint256 offset = (-params.usdDelta).toUint256();
            longOpenInterest += offset;
            shortOpenInterest += offset;
        }

        return getNextOpenInterestParams(params, longOpenInterest, shortOpenInterest);
    }

    function getNextOpenInterestParams(
        GetPriceImpactUsdParams memory params,
        uint256 longOpenInterest,
        uint256 shortOpenInterest
    ) internal pure returns (OpenInterestParams memory) {
        uint256 nextLongOpenInterest = longOpenInterest;
        uint256 nextShortOpenInterest = shortOpenInterest;

        if (params.isLong) {
            if (params.usdDelta < 0 && (-params.usdDelta).toUint256() > longOpenInterest) {
                revert Errors.UsdDeltaExceedsLongOpenInterest(params.usdDelta, longOpenInterest);
            }

            nextLongOpenInterest = Calc.sumReturnUint256(longOpenInterest, params.usdDelta);
        } else {
            if (params.usdDelta < 0 && (-params.usdDelta).toUint256() > shortOpenInterest) {
                revert Errors.UsdDeltaExceedsShortOpenInterest(params.usdDelta, shortOpenInterest);
            }

            nextShortOpenInterest = Calc.sumReturnUint256(shortOpenInterest, params.usdDelta);
        }

        OpenInterestParams memory openInterestParams = OpenInterestParams(
            longOpenInterest,
            shortOpenInterest,
            nextLongOpenInterest,
            nextShortOpenInterest
        );

        return openInterestParams;
    }

    // @dev get position fees
    // @param dataStore DataStore
    // @param referralStorage IReferralStorage
    // @param position the position values
    // @param collateralTokenPrice the price of the position's collateralToken
    // @param longToken the long token of the market
    // @param shortToken the short token of the market
    // @param sizeDeltaUsd the change in position size
    // @return PositionFees
    function getPositionFees(
        GetPositionFeesParams memory params
    ) internal view returns (PositionFees memory) {
        PositionFees memory fees = getPositionFeesAfterReferral(
            params.dataStore,
            params.referralStorage,
            params.collateralTokenPrice,
            params.balanceWasImproved,
            params.position.account(),
            params.position.market(),
            params.sizeDeltaUsd
        );

        uint256 borrowingFeeUsd = MarketUtils.getBorrowingFees(params.dataStore, params.position);

        fees.borrowing = getBorrowingFees(
            params.dataStore,
            params.collateralTokenPrice,
            borrowingFeeUsd
        );

        if (params.isLiquidation) {
            fees.liquidation = getLiquidationFees(params.dataStore, params.position.market(), params.sizeDeltaUsd, params.collateralTokenPrice);
        }

        fees.feeAmountForPool =
            fees.positionFeeAmountForPool +
            fees.borrowing.borrowingFeeAmount -
            fees.borrowing.borrowingFeeAmountForFeeReceiver +
            fees.liquidation.liquidationFeeAmount -
            fees.liquidation.liquidationFeeAmountForFeeReceiver;

        fees.feeReceiverAmount +=
            fees.borrowing.borrowingFeeAmountForFeeReceiver +
            fees.liquidation.liquidationFeeAmountForFeeReceiver;

        fees.funding.latestFundingFeeAmountPerSize = MarketUtils.getFundingFeeAmountPerSize(
            params.dataStore,
            params.position.market(),
            params.position.collateralToken(),
            params.position.isLong()
        );

        fees.funding.latestLongTokenClaimableFundingAmountPerSize = MarketUtils.getClaimableFundingAmountPerSize(
            params.dataStore,
            params.position.market(),
            params.longToken,
            params.position.isLong()
        );

        fees.funding.latestShortTokenClaimableFundingAmountPerSize = MarketUtils.getClaimableFundingAmountPerSize(
            params.dataStore,
            params.position.market(),
            params.shortToken,
            params.position.isLong()
        );

        fees.funding = getFundingFees(
            fees.funding,
            params.position
        );

        fees.ui = getUiFees(
            params.dataStore,
            params.collateralTokenPrice,
            params.sizeDeltaUsd,
            params.uiFeeReceiver
        );

        fees.totalCostAmountExcludingFunding =
            fees.positionFeeAmount
            + fees.borrowing.borrowingFeeAmount
            + fees.liquidation.liquidationFeeAmount
            + fees.ui.uiFeeAmount
            - fees.totalDiscountAmount;

        fees.totalCostAmount =
            fees.totalCostAmountExcludingFunding
            + fees.funding.fundingFeeAmount;

        return fees;
    }

    function getBorrowingFees(
        DataStore dataStore,
        Price.Props memory collateralTokenPrice,
        uint256 borrowingFeeUsd
    ) internal view returns (PositionBorrowingFees memory) {
        PositionBorrowingFees memory borrowingFees;

        borrowingFees.borrowingFeeUsd = borrowingFeeUsd;
        borrowingFees.borrowingFeeAmount = borrowingFeeUsd / collateralTokenPrice.min;
        borrowingFees.borrowingFeeReceiverFactor = dataStore.getUint(Keys.BORROWING_FEE_RECEIVER_FACTOR);
        borrowingFees.borrowingFeeAmountForFeeReceiver = Precision.applyFactor(borrowingFees.borrowingFeeAmount, borrowingFees.borrowingFeeReceiverFactor);

        return borrowingFees;
    }

    function getFundingFees(
        PositionFundingFees memory fundingFees,
        Position.Props memory position
    ) internal pure returns (PositionFundingFees memory) {
        fundingFees.fundingFeeAmount = MarketUtils.getFundingAmount(
            fundingFees.latestFundingFeeAmountPerSize,
            position.fundingFeeAmountPerSize(),
            position.sizeInUsd(),
            true // roundUpMagnitude
        );

        fundingFees.claimableLongTokenAmount = MarketUtils.getFundingAmount(
            fundingFees.latestLongTokenClaimableFundingAmountPerSize,
            position.longTokenClaimableFundingAmountPerSize(),
            position.sizeInUsd(),
            false // roundUpMagnitude
        );

        fundingFees.claimableShortTokenAmount = MarketUtils.getFundingAmount(
            fundingFees.latestShortTokenClaimableFundingAmountPerSize,
            position.shortTokenClaimableFundingAmountPerSize(),
            position.sizeInUsd(),
            false // roundUpMagnitude
        );

        return fundingFees;
    }

    function getUiFees(
        DataStore dataStore,
        Price.Props memory collateralTokenPrice,
        uint256 sizeDeltaUsd,
        address uiFeeReceiver
    ) internal view returns (PositionUiFees memory) {
        PositionUiFees memory uiFees;

        if (uiFeeReceiver == address(0)) {
            return uiFees;
        }

        uiFees.uiFeeReceiver = uiFeeReceiver;
        uiFees.uiFeeReceiverFactor = MarketUtils.getUiFeeFactor(dataStore, uiFeeReceiver);
        uiFees.uiFeeAmount = Precision.applyFactor(sizeDeltaUsd, uiFees.uiFeeReceiverFactor) / collateralTokenPrice.min;

        return uiFees;
    }

    // @dev get position fees after applying referral rebates / discounts
    // @param dataStore DataStore
    // @param referralStorage IReferralStorage
    // @param collateralTokenPrice the price of the position's collateralToken
    // @param the position's account
    // @param market the position's market
    // @param sizeDeltaUsd the change in position size
    // @return (affiliate, traderDiscountAmount, affiliateRewardAmount, feeReceiverAmount, positionFeeAmountForPool)
    function getPositionFeesAfterReferral(
        DataStore dataStore,
        IReferralStorage referralStorage,
        Price.Props memory collateralTokenPrice,
        bool balanceWasImproved,
        address account,
        address market,
        uint256 sizeDeltaUsd
    ) internal view returns (PositionFees memory) {
        PositionFees memory fees;

        fees.collateralTokenPrice = collateralTokenPrice;

        fees.referral.trader = account;
        uint256 minAffiliateRewardFactor;
        (
            fees.referral.referralCode,
            fees.referral.affiliate,
            fees.referral.affiliateRewardFactor,
            fees.referral.traderDiscountFactor,
            minAffiliateRewardFactor
        ) = ReferralUtils.getReferralInfo(dataStore, referralStorage, account);

        // note that since it is possible to incur both positive and negative price impact values
        // and the negative price impact factor may be larger than the positive impact factor
        // it is possible for the balance to be improved overall but for the price impact to still be negative
        // in this case the fee factor for the negative price impact would be charged
        // a user could split the order into two, to incur a smaller fee, reducing the fee through this should not be a large issue
        fees.positionFeeFactor = dataStore.getUint(Keys.positionFeeFactorKey(market, balanceWasImproved));
        fees.positionFeeAmount = Precision.applyFactor(sizeDeltaUsd, fees.positionFeeFactor) / collateralTokenPrice.min;

        // pro tiers are provided as a flexible option to allow for custom criteria based discounts,
        // the exact criteria and usage of this feature should be decided by the DAO
        fees.pro.traderTier = dataStore.getUint(Keys.proTraderTierKey(account));
        if (fees.pro.traderTier > 0) {
            fees.pro.traderDiscountFactor = dataStore.getUint(Keys.proDiscountFactorKey(fees.pro.traderTier));

            if (fees.pro.traderDiscountFactor > 0) {
                fees.pro.traderDiscountAmount = Precision.applyFactor(fees.positionFeeAmount, fees.pro.traderDiscountFactor);
            }
        }

        // if pro discount is higher than referral discount then affiliate reward is capped at (total referral rebate - pro discount)
        // but can not be lower than configured min affiliate reward
        //
        // example 1:
        // referral code is 10% affiliate reward and 10% trader discount, pro discount is 5%
        // min affiliate reward 5%, total referral rebate is 20%, affiliate reward cap is max of (20% - 5%, 5%) = 15%
        // trader gets 10% discount, affiliate reward is capped at 15%, affiliate gets full 10% reward
        // protocol gets 80%
        //
        // example 2:
        // referral code is 10% affiliate reward and 10% trader discount, pro discount is 13%
        // min affiliate reward 5%, total referral rebate is 20%, affiliate reward cap is max of (20% - 13%, 5%) = 7%
        // trader gets 13% discount, affiliate reward is capped at 7%, affiliate gets capped 7% reward
        // protocol gets 80%
        //
        // example 3:
        // referral code is 10% affiliate reward and 10% trader discount, pro discount is 18%
        // min affiliate reward 5%, total referral rebate is 20%, affiliate reward cap is max of (20% - 18%, 5%) = 5%
        // trader gets 18% discount, affiliate reward is capped at 5%, affiliate gets capped 5% reward
        // protocol gets 77%
        //
        // example 4:
        // referral code is 10% affiliate reward and 10% trader discount, pro discount is 25%
        // min affiliate reward 5%, total referral rebate is 20%, affiliate reward cap is max of (20% - 25%, 5%) = 5%
        // trader gets 25% discount, affiliate reward is capped at 5%, affiliate gets capped 5% reward
        // protocol gets 70%

        if (fees.referral.referralCode != bytes32(0)) {
            fees.referral.adjustedAffiliateRewardFactor = fees.referral.affiliateRewardFactor;
            fees.referral.totalRebateFactor = fees.referral.affiliateRewardFactor + fees.referral.traderDiscountFactor;
            // if pro discount is higher than referral discount then affiliate reward should be capped
            // at max of (min affiliate reward, total referral rebate - pro discount)
            if (fees.pro.traderDiscountFactor > fees.referral.traderDiscountFactor) {
                fees.referral.adjustedAffiliateRewardFactor = fees.pro.traderDiscountFactor > fees.referral.totalRebateFactor
                    ? minAffiliateRewardFactor
                    : fees.referral.totalRebateFactor - fees.pro.traderDiscountFactor;
                if (fees.referral.adjustedAffiliateRewardFactor < minAffiliateRewardFactor) {
                    fees.referral.adjustedAffiliateRewardFactor = minAffiliateRewardFactor;
                }
            }

            fees.referral.affiliateRewardAmount = Precision.applyFactor(fees.positionFeeAmount, fees.referral.adjustedAffiliateRewardFactor);
            fees.referral.traderDiscountAmount = Precision.applyFactor(fees.positionFeeAmount, fees.referral.traderDiscountFactor);
            fees.referral.totalRebateAmount = fees.referral.affiliateRewardAmount + fees.referral.traderDiscountAmount;
        }

        fees.totalDiscountAmount = fees.pro.traderDiscountAmount > fees.referral.traderDiscountAmount
            ? fees.pro.traderDiscountAmount
            : fees.referral.traderDiscountAmount;
        fees.protocolFeeAmount = fees.positionFeeAmount - fees.referral.affiliateRewardAmount - fees.totalDiscountAmount;

        fees.positionFeeReceiverFactor = dataStore.getUint(Keys.POSITION_FEE_RECEIVER_FACTOR);
        fees.feeReceiverAmount = Precision.applyFactor(fees.protocolFeeAmount, fees.positionFeeReceiverFactor);
        fees.positionFeeAmountForPool = fees.protocolFeeAmount - fees.feeReceiverAmount;

        return fees;
    }

    function getLiquidationFees(DataStore dataStore, address market, uint256 sizeInUsd, Price.Props memory collateralTokenPrice) internal view returns (PositionLiquidationFees memory) {
        PositionLiquidationFees memory liquidationFees;
        uint256 liquidationFeeFactor = dataStore.getUint(Keys.liquidationFeeFactorKey(market));
        if (liquidationFeeFactor == 0) {
            return liquidationFees;
        }

        liquidationFees.liquidationFeeUsd = Precision.applyFactor(sizeInUsd, liquidationFeeFactor);
        liquidationFees.liquidationFeeAmount = Calc.roundUpDivision(liquidationFees.liquidationFeeUsd, collateralTokenPrice.min);
        liquidationFees.liquidationFeeReceiverFactor = dataStore.getUint(Keys.LIQUIDATION_FEE_RECEIVER_FACTOR);
        liquidationFees.liquidationFeeAmountForFeeReceiver = Precision.applyFactor(liquidationFees.liquidationFeeAmount, liquidationFees.liquidationFeeReceiverFactor);
        return liquidationFees;
    }
}
