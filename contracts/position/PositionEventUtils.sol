// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";

import "./Position.sol";
import "./PositionUtils.sol";
import "../pricing/PositionPricingUtils.sol";

library PositionEventUtils {
    using Position for Position.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    struct PositionIncreaseParams {
        EventEmitter eventEmitter;
        bytes32 orderKey;
        bytes32 positionKey;
        Position.Props position;
        Price.Props indexTokenPrice;
        Price.Props collateralTokenPrice;
        uint256 executionPrice;
        uint256 sizeDeltaUsd;
        uint256 sizeDeltaInTokens;
        int256 collateralDeltaAmount;
        int256 priceImpactUsd;
        int256 priceImpactAmount;
        Order.OrderType orderType;
    }

    function emitPositionIncrease(PositionIncreaseParams memory params) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "account", params.position.account());
        eventData.addressItems.setItem(1, "market", params.position.market());
        eventData.addressItems.setItem(2, "collateralToken", params.position.collateralToken());

        eventData.uintItems.initItems(16);
        eventData.uintItems.setItem(0, "sizeInUsd", params.position.sizeInUsd());
        eventData.uintItems.setItem(1, "sizeInTokens", params.position.sizeInTokens());
        eventData.uintItems.setItem(2, "collateralAmount", params.position.collateralAmount());
        eventData.uintItems.setItem(3, "borrowingFactor", params.position.borrowingFactor());
        eventData.uintItems.setItem(4, "fundingFeeAmountPerSize", params.position.fundingFeeAmountPerSize());
        eventData.uintItems.setItem(5, "longTokenClaimableFundingAmountPerSize", params.position.longTokenClaimableFundingAmountPerSize());
        eventData.uintItems.setItem(6, "shortTokenClaimableFundingAmountPerSize", params.position.shortTokenClaimableFundingAmountPerSize());
        eventData.uintItems.setItem(7, "executionPrice", params.executionPrice);
        eventData.uintItems.setItem(8, "indexTokenPrice.max", params.indexTokenPrice.max);
        eventData.uintItems.setItem(9, "indexTokenPrice.min", params.indexTokenPrice.min);
        eventData.uintItems.setItem(10, "collateralTokenPrice.max", params.collateralTokenPrice.max);
        eventData.uintItems.setItem(11, "collateralTokenPrice.min", params.collateralTokenPrice.min);
        eventData.uintItems.setItem(12, "sizeDeltaUsd", params.sizeDeltaUsd);
        eventData.uintItems.setItem(13, "sizeDeltaInTokens", params.sizeDeltaInTokens);
        eventData.uintItems.setItem(14, "orderType", uint256(params.orderType));
        eventData.uintItems.setItem(15, "increasedAtTime", uint256(params.position.increasedAtTime()));

        eventData.intItems.initItems(3);
        eventData.intItems.setItem(0, "collateralDeltaAmount", params.collateralDeltaAmount);
        eventData.intItems.setItem(1, "priceImpactUsd", params.priceImpactUsd);
        eventData.intItems.setItem(2, "priceImpactAmount", params.priceImpactAmount);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", params.position.isLong());

        eventData.bytes32Items.initItems(2);
        eventData.bytes32Items.setItem(0, "orderKey", params.orderKey);
        eventData.bytes32Items.setItem(1, "positionKey", params.positionKey);

        params.eventEmitter.emitEventLog1(
            "PositionIncrease",
            Cast.toBytes32(params.position.account()),
            eventData
        );
    }

    function emitPositionDecrease(
        EventEmitter eventEmitter,
        bytes32 orderKey,
        bytes32 positionKey,
        Position.Props memory position,
        uint256 sizeDeltaUsd,
        uint256 collateralDeltaAmount,
        Order.OrderType orderType,
        PositionUtils.DecreasePositionCollateralValues memory values,
        Price.Props memory indexTokenPrice,
        Price.Props memory collateralTokenPrice
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "account", position.account());
        eventData.addressItems.setItem(1, "market", position.market());
        eventData.addressItems.setItem(2, "collateralToken", position.collateralToken());

        eventData.uintItems.initItems(18);
        eventData.uintItems.setItem(0, "sizeInUsd", position.sizeInUsd());
        eventData.uintItems.setItem(1, "sizeInTokens", position.sizeInTokens());
        eventData.uintItems.setItem(2, "collateralAmount", position.collateralAmount());
        eventData.uintItems.setItem(3, "borrowingFactor", position.borrowingFactor());
        eventData.uintItems.setItem(4, "fundingFeeAmountPerSize", position.fundingFeeAmountPerSize());
        eventData.uintItems.setItem(5, "longTokenClaimableFundingAmountPerSize", position.longTokenClaimableFundingAmountPerSize());
        eventData.uintItems.setItem(6, "shortTokenClaimableFundingAmountPerSize", position.shortTokenClaimableFundingAmountPerSize());
        eventData.uintItems.setItem(7, "executionPrice", values.executionPrice);
        eventData.uintItems.setItem(8, "indexTokenPrice.max", indexTokenPrice.max);
        eventData.uintItems.setItem(9, "indexTokenPrice.min", indexTokenPrice.min);
        eventData.uintItems.setItem(10, "collateralTokenPrice.max", collateralTokenPrice.max);
        eventData.uintItems.setItem(11, "collateralTokenPrice.min", collateralTokenPrice.min);
        eventData.uintItems.setItem(12, "sizeDeltaUsd", sizeDeltaUsd);
        eventData.uintItems.setItem(13, "sizeDeltaInTokens", values.sizeDeltaInTokens);
        eventData.uintItems.setItem(14, "collateralDeltaAmount", collateralDeltaAmount);
        eventData.uintItems.setItem(15, "values.priceImpactDiffUsd", values.priceImpactDiffUsd);
        eventData.uintItems.setItem(16, "orderType", uint256(orderType));
        eventData.uintItems.setItem(17, "decreasedAtTime", position.decreasedAtTime());

        eventData.intItems.initItems(4);
        eventData.intItems.setItem(0, "priceImpactUsd", values.priceImpactUsd);
        eventData.intItems.setItem(1, "basePnlUsd", values.basePnlUsd);
        eventData.intItems.setItem(2, "uncappedBasePnlUsd", values.uncappedBasePnlUsd);
        eventData.intItems.setItem(3, "proportionalImpactPendingUsd", values.proportionalImpactPendingUsd);

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isLong", position.isLong());

        eventData.bytes32Items.initItems(2);
        eventData.bytes32Items.setItem(0, "orderKey", orderKey);
        eventData.bytes32Items.setItem(1, "positionKey", positionKey);

        eventEmitter.emitEventLog1(
            "PositionDecrease",
            Cast.toBytes32(position.account()),
            eventData
        );
    }

    function emitInsolventClose(
        EventEmitter eventEmitter,
        bytes32 orderKey,
        uint256 positionCollateralAmount,
        int256 basePnlUsd,
        uint256 remainingCostUsd,
        string memory step
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "orderKey", orderKey);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "positionCollateralAmount", positionCollateralAmount);
        eventData.uintItems.setItem(1, "remainingCostUsd", remainingCostUsd);

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "basePnlUsd", basePnlUsd);

        eventData.stringItems.initItems(1);
        eventData.stringItems.setItem(0, "step", step);

        eventEmitter.emitEventLog(
            "InsolventClose",
            eventData
        );
    }

    function emitInsufficientFundingFeePayment(
        EventEmitter eventEmitter,
        address market,
        address token,
        uint256 expectedAmount,
        uint256 amountPaidInCollateralToken,
        uint256 amountPaidInSecondaryOutputToken
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "token", token);

        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "expectedAmount", expectedAmount);
        eventData.uintItems.setItem(1, "amountPaidInCollateralToken", amountPaidInCollateralToken);
        eventData.uintItems.setItem(2, "amountPaidInSecondaryOutputToken", amountPaidInSecondaryOutputToken);

        eventEmitter.emitEventLog1(
            "InsufficientFundingFeePayment",
            Cast.toBytes32(market),
            eventData
        );
    }

    function emitPositionFeesCollected(
        EventEmitter eventEmitter,
        bytes32 orderKey,
        bytes32 positionKey,
        address market,
        address collateralToken,
        uint256 tradeSizeUsd,
        bool isIncrease,
        PositionPricingUtils.PositionFees memory fees
    ) external {
        _emitPositionFees(
            eventEmitter,
            orderKey,
            positionKey,
            market,
            collateralToken,
            tradeSizeUsd,
            isIncrease,
            fees,
            "PositionFeesCollected"
        );
    }

    function emitPositionFeesInfo(
        EventEmitter eventEmitter,
        bytes32 orderKey,
        bytes32 positionKey,
        address market,
        address collateralToken,
        uint256 tradeSizeUsd,
        bool isIncrease,
        PositionPricingUtils.PositionFees memory fees
    ) external {
        _emitPositionFees(
            eventEmitter,
            orderKey,
            positionKey,
            market,
            collateralToken,
            tradeSizeUsd,
            isIncrease,
            fees,
            "PositionFeesInfo"
        );
    }

    function _emitPositionFees(
        EventEmitter eventEmitter,
        bytes32 orderKey,
        bytes32 positionKey,
        address market,
        address collateralToken,
        uint256 tradeSizeUsd,
        bool isIncrease,
        PositionPricingUtils.PositionFees memory fees,
        string memory eventName
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(3);
        eventData.bytes32Items.setItem(0, "orderKey", orderKey);
        eventData.bytes32Items.setItem(1, "positionKey", positionKey);
        eventData.bytes32Items.setItem(2, "referralCode", fees.referral.referralCode);

        eventData.addressItems.initItems(5);
        eventData.addressItems.setItem(0, "market", market);
        eventData.addressItems.setItem(1, "collateralToken", collateralToken);
        eventData.addressItems.setItem(2, "affiliate", fees.referral.affiliate);
        eventData.addressItems.setItem(3, "trader", fees.referral.trader);
        eventData.addressItems.setItem(4, "uiFeeReceiver", fees.ui.uiFeeReceiver);

        // in case the position was insolvent, the fundingFeeAmount and feeAmountForPool
        // values may not be accurate

        uint256 uintItemsCount = 23;
        uint256 dynamicItemIndex = uintItemsCount - 1;
        if (fees.referral.totalRebateFactor > 0) {
            uintItemsCount += 6;
        }
        if (fees.liquidation.liquidationFeeAmount > 0) {
            uintItemsCount += 3;
        }
        if (fees.pro.traderDiscountFactor > 0) {
            uintItemsCount += 2;
        }

        eventData.uintItems.initItems(uintItemsCount);
        eventData.uintItems.setItem(0, "collateralTokenPrice.min", fees.collateralTokenPrice.min);
        eventData.uintItems.setItem(1, "collateralTokenPrice.max", fees.collateralTokenPrice.max);
        eventData.uintItems.setItem(2, "tradeSizeUsd", tradeSizeUsd);
        eventData.uintItems.setItem(3, "fundingFeeAmount", fees.funding.fundingFeeAmount);
        eventData.uintItems.setItem(4, "claimableLongTokenAmount", fees.funding.claimableLongTokenAmount);
        eventData.uintItems.setItem(5, "claimableShortTokenAmount", fees.funding.claimableShortTokenAmount);
        eventData.uintItems.setItem(6, "latestFundingFeeAmountPerSize", fees.funding.latestFundingFeeAmountPerSize);
        eventData.uintItems.setItem(7, "latestLongTokenClaimableFundingAmountPerSize", fees.funding.latestLongTokenClaimableFundingAmountPerSize);
        eventData.uintItems.setItem(8, "latestShortTokenClaimableFundingAmountPerSize", fees.funding.latestShortTokenClaimableFundingAmountPerSize);
        eventData.uintItems.setItem(9, "borrowingFeeUsd", fees.borrowing.borrowingFeeUsd);
        eventData.uintItems.setItem(10, "borrowingFeeAmount", fees.borrowing.borrowingFeeAmount);
        eventData.uintItems.setItem(11, "borrowingFeeReceiverFactor", fees.borrowing.borrowingFeeReceiverFactor);
        eventData.uintItems.setItem(12, "borrowingFeeAmountForFeeReceiver", fees.borrowing.borrowingFeeAmountForFeeReceiver);
        eventData.uintItems.setItem(13, "positionFeeFactor", fees.positionFeeFactor);
        eventData.uintItems.setItem(14, "protocolFeeAmount", fees.protocolFeeAmount);
        eventData.uintItems.setItem(15, "positionFeeReceiverFactor", fees.positionFeeReceiverFactor);
        eventData.uintItems.setItem(16, "feeReceiverAmount", fees.feeReceiverAmount);
        eventData.uintItems.setItem(17, "feeAmountForPool", fees.feeAmountForPool);
        eventData.uintItems.setItem(18, "positionFeeAmountForPool", fees.positionFeeAmountForPool);
        eventData.uintItems.setItem(19, "positionFeeAmount", fees.positionFeeAmount);
        eventData.uintItems.setItem(20, "totalCostAmount", fees.totalCostAmount);
        eventData.uintItems.setItem(21, "uiFeeReceiverFactor", fees.ui.uiFeeReceiverFactor);
        eventData.uintItems.setItem(22, "uiFeeAmount", fees.ui.uiFeeAmount);

        // ++dynamicItemIndex is pre-increment, first the value is incremented, then updated value is returned
        // i.e. if dynamicItemIndex is 22, then ++dynamicItemIndex returns 23
        if (fees.referral.totalRebateFactor > 0) {
            eventData.uintItems.setItem(++dynamicItemIndex, "referral.totalRebateFactor", fees.referral.totalRebateFactor);
            eventData.uintItems.setItem(++dynamicItemIndex, "referral.adjustedAffiliateRewardFactor", fees.referral.adjustedAffiliateRewardFactor);
            eventData.uintItems.setItem(++dynamicItemIndex, "referral.traderDiscountFactor", fees.referral.traderDiscountFactor);
            eventData.uintItems.setItem(++dynamicItemIndex, "referral.totalRebateAmount", fees.referral.totalRebateAmount);
            eventData.uintItems.setItem(++dynamicItemIndex, "referral.traderDiscountAmount", fees.referral.traderDiscountAmount);
            eventData.uintItems.setItem(++dynamicItemIndex, "referral.affiliateRewardAmount", fees.referral.affiliateRewardAmount);
        }
        if (fees.pro.traderDiscountFactor > 0) {
            eventData.uintItems.setItem(++dynamicItemIndex, "pro.traderDiscountFactor", fees.pro.traderDiscountFactor);
            eventData.uintItems.setItem(++dynamicItemIndex, "pro.traderDiscountAmount", fees.pro.traderDiscountAmount);
        }
        if (fees.liquidation.liquidationFeeAmount > 0) {
            eventData.uintItems.setItem(++dynamicItemIndex, "liquidationFeeAmount", fees.liquidation.liquidationFeeAmount);
            eventData.uintItems.setItem(++dynamicItemIndex, "liquidationFeeReceiverFactor", fees.liquidation.liquidationFeeReceiverFactor);
            eventData.uintItems.setItem(++dynamicItemIndex, "liquidationFeeAmountForFeeReceiver", fees.liquidation.liquidationFeeAmountForFeeReceiver);
        }

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "isIncrease", isIncrease);

        eventEmitter.emitEventLog1(
            eventName,
            Cast.toBytes32(market),
            eventData
        );
    }
}
