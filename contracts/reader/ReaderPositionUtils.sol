// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../market/MarketStoreUtils.sol";

import "../position/Position.sol";
import "../position/PositionUtils.sol";
import "../position/PositionStoreUtils.sol";

import "../market/MarketUtils.sol";
import "../market/Market.sol";
import "./ReaderPricingUtils.sol";

library ReaderPositionUtils {
    using Position for Position.Props;
    using SafeCast for uint256;

    struct PositionInfo {
        bytes32 positionKey;
        Position.Props position;
        PositionPricingUtils.PositionFees fees;
        ReaderPricingUtils.ExecutionPriceResult executionPriceResult;
        int256 basePnlUsd;
        int256 uncappedBasePnlUsd;
        int256 pnlAfterPriceImpactUsd;
    }

    struct GetPositionInfoCache {
        Market.Props market;
        Price.Props collateralTokenPrice;
        uint256 pendingBorrowingFeeUsd;
    }

    function getNextBorrowingFees(
        DataStore dataStore,
        Position.Props memory position,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices
    ) internal view returns (uint256) {
        return MarketUtils.getNextBorrowingFees(
            dataStore,
            position,
            market,
            prices
        );
    }

    function getBorrowingFees(
        DataStore dataStore,
        Price.Props memory collateralTokenPrice,
        uint256 borrowingFeeUsd
    ) internal view returns (PositionPricingUtils.PositionBorrowingFees memory) {
        return PositionPricingUtils.getBorrowingFees(
            dataStore,
            collateralTokenPrice,
            borrowingFeeUsd
        );
    }

    function getPositionInfoList(
        DataStore dataStore,
        IReferralStorage referralStorage,
        bytes32[] memory positionKeys,
        MarketUtils.MarketPrices[] memory prices,
        address uiFeeReceiver
    ) external view returns (ReaderPositionUtils.PositionInfo[] memory) {
        ReaderPositionUtils.PositionInfo[] memory positionInfoList = new ReaderPositionUtils.PositionInfo[](positionKeys.length);
        for (uint256 i; i < positionKeys.length; i++) {
            bytes32 positionKey = positionKeys[i];
            positionInfoList[i] = getPositionInfo(
                dataStore,
                referralStorage,
                positionKey,
                prices[i],
                0, // sizeDeltaUsd
                uiFeeReceiver,
                true // usePositionSizeAsSizeDeltaUsd
            );
        }

        return positionInfoList;
    }

    function getAccountPositionInfoList(
        DataStore dataStore,
        IReferralStorage referralStorage,
        address account,
        address[] memory markets,
        MarketUtils.MarketPrices[] memory marketPrices,
        address uiFeeReceiver,
        uint256 start,
        uint256 end
    ) external view returns (ReaderPositionUtils.PositionInfo[] memory) {
        bytes32[] memory positionKeys = PositionStoreUtils.getAccountPositionKeys(dataStore, account, start, end);
        ReaderPositionUtils.PositionInfo[] memory positionInfoList = new ReaderPositionUtils.PositionInfo[](positionKeys.length);
        for (uint256 i; i < positionKeys.length; i++) {
            bytes32 positionKey = positionKeys[i];
            Position.Props memory position = PositionStoreUtils.get(dataStore, positionKey);
            MarketUtils.MarketPrices memory prices = _getMarketPricesByAddress(markets, marketPrices, position.market());
            positionInfoList[i] = getPositionInfo(
                dataStore,
                referralStorage,
                position,
                prices,
                0, // sizeDeltaUsd
                uiFeeReceiver,
                true // usePositionSizeAsSizeDeltaUsd
            );
        }

        return positionInfoList;
    }

    function _getMarketPricesByAddress(
        address[] memory markets,
        MarketUtils.MarketPrices[] memory marketPrices,
        address market
    ) internal pure returns (MarketUtils.MarketPrices memory) {
        for (uint256 i = 0; i < markets.length; i++) {
            address currentMarket = markets[i];
            if (currentMarket == market) {
                return marketPrices[i];
            }
        }

        revert Errors.EmptyMarketPrice(market);
    }

    function getNextFundingAmountPerSize(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices
    ) public view returns (MarketUtils.GetNextFundingAmountPerSizeResult memory) {
        return MarketUtils.getNextFundingAmountPerSize(
            dataStore,
            market,
            prices
        );
    }

    function getAccountPositions(
        DataStore dataStore,
        address account,
        uint256 start,
        uint256 end
    ) external view returns (Position.Props[] memory) {
        bytes32[] memory positionKeys = PositionStoreUtils.getAccountPositionKeys(dataStore, account, start, end);
        Position.Props[] memory positions = new Position.Props[](positionKeys.length);
        for (uint256 i; i < positionKeys.length; i++) {
            bytes32 positionKey = positionKeys[i];
            positions[i] = PositionStoreUtils.get(dataStore, positionKey);
        }

        return positions;
    }

    function getPositionInfo(
        DataStore dataStore,
        IReferralStorage referralStorage,
        bytes32 positionKey,
        MarketUtils.MarketPrices memory prices,
        uint256 sizeDeltaUsd,
        address uiFeeReceiver,
        bool usePositionSizeAsSizeDeltaUsd
    ) public view returns (PositionInfo memory) {
        Position.Props memory position = PositionStoreUtils.get(dataStore, positionKey);
        return getPositionInfo(
            dataStore,
            referralStorage,
            position,
            prices,
            sizeDeltaUsd,
            uiFeeReceiver,
            usePositionSizeAsSizeDeltaUsd
        );
    }

    function getPositionInfo(
        DataStore dataStore,
        IReferralStorage referralStorage,
        Position.Props memory position,
        MarketUtils.MarketPrices memory prices,
        uint256 sizeDeltaUsd,
        address uiFeeReceiver,
        bool usePositionSizeAsSizeDeltaUsd
    ) internal view returns (PositionInfo memory) {
        if (position.account() == address(0)) {
            revert Errors.EmptyPosition();
        }

        PositionInfo memory positionInfo;
        GetPositionInfoCache memory cache;

        positionInfo.position = position;
        cache.market = MarketStoreUtils.get(dataStore, positionInfo.position.market());
        cache.collateralTokenPrice = MarketUtils.getCachedTokenPrice(positionInfo.position.collateralToken(), cache.market, prices);

        if (usePositionSizeAsSizeDeltaUsd) {
            sizeDeltaUsd = positionInfo.position.sizeInUsd();
        }

        positionInfo.executionPriceResult = ReaderPricingUtils.getExecutionPrice(
            dataStore,
            cache.market,
            prices.indexTokenPrice,
            positionInfo.position.sizeInUsd(),
            positionInfo.position.sizeInTokens(),
            -sizeDeltaUsd.toInt256(),
            positionInfo.position.isLong()
        );

        PositionPricingUtils.GetPositionFeesParams memory getPositionFeesParams = PositionPricingUtils.GetPositionFeesParams({
            dataStore: dataStore,
            referralStorage: referralStorage,
            position: positionInfo.position,
            collateralTokenPrice: cache.collateralTokenPrice,
            forPositiveImpact: positionInfo.executionPriceResult.priceImpactUsd > 0,
            longToken: cache.market.longToken,
            shortToken: cache.market.shortToken,
            sizeDeltaUsd: sizeDeltaUsd,
            uiFeeReceiver: uiFeeReceiver,
            isLiquidation: false
        });

        positionInfo.fees = PositionPricingUtils.getPositionFees(getPositionFeesParams);

        // borrowing and funding fees need to be overwritten with pending values otherwise they
        // would be using storage values that have not yet been updated
        cache.pendingBorrowingFeeUsd = getNextBorrowingFees(dataStore, positionInfo.position, cache.market, prices);

        positionInfo.fees.borrowing = getBorrowingFees(
            dataStore,
            cache.collateralTokenPrice,
            cache.pendingBorrowingFeeUsd
        );

        MarketUtils.GetNextFundingAmountPerSizeResult memory nextFundingAmountResult = getNextFundingAmountPerSize(dataStore, cache.market, prices);

        positionInfo.fees.funding.latestFundingFeeAmountPerSize = MarketUtils.getFundingFeeAmountPerSize(
            dataStore,
            positionInfo.position.market(),
            positionInfo.position.collateralToken(),
            positionInfo.position.isLong()
        );

        positionInfo.fees.funding.latestLongTokenClaimableFundingAmountPerSize = MarketUtils.getClaimableFundingAmountPerSize(
            dataStore,
            positionInfo.position.market(),
            cache.market.longToken,
            positionInfo.position.isLong()
        );

        positionInfo.fees.funding.latestShortTokenClaimableFundingAmountPerSize = MarketUtils.getClaimableFundingAmountPerSize(
            dataStore,
            positionInfo.position.market(),
            cache.market.shortToken,
            positionInfo.position.isLong()
        );

        // see MarketUtils.getNextFundingAmountPerSize for more info on why this multiplier is needed
        // a short summary:
        // - funding values are split based on long and short token
        // - for single token markets, these tokens are the same
        // - so when the funding values are applied in updateFundingState, they are applied twice
        // - e.g.
        //     - increase fundingFeeAmountPerSize(market, collateralToken: token0, isLong: true) by 10
        //     - increase fundingFeeAmountPerSize(market, collateralToken: token1, isLong: true) by 10
        //     - for a single token market, token0 is the same as token1, so the value would be increased by 20
        // - to avoid costs being doubled, these values are halved in MarketUtils.getNextFundingAmountPerSize
        // - the reader code needs to double the values, because in the code below the nextFundingAmountResult
        // values are applied virtually instead of the DataStore values being updated
        uint256 multiplier = cache.market.longToken == cache.market.shortToken ? 2 : 1;

        if (positionInfo.position.isLong()) {
            positionInfo.fees.funding.latestLongTokenClaimableFundingAmountPerSize += nextFundingAmountResult.claimableFundingAmountPerSizeDelta.long.longToken * multiplier;
            positionInfo.fees.funding.latestShortTokenClaimableFundingAmountPerSize += nextFundingAmountResult.claimableFundingAmountPerSizeDelta.long.shortToken * multiplier;

            if (positionInfo.position.collateralToken() == cache.market.longToken) {
                positionInfo.fees.funding.latestFundingFeeAmountPerSize += nextFundingAmountResult.fundingFeeAmountPerSizeDelta.long.longToken * multiplier;
            } else {
                positionInfo.fees.funding.latestFundingFeeAmountPerSize += nextFundingAmountResult.fundingFeeAmountPerSizeDelta.long.shortToken * multiplier;
            }
        } else {
            positionInfo.fees.funding.latestLongTokenClaimableFundingAmountPerSize += nextFundingAmountResult.claimableFundingAmountPerSizeDelta.short.longToken * multiplier;
            positionInfo.fees.funding.latestShortTokenClaimableFundingAmountPerSize += nextFundingAmountResult.claimableFundingAmountPerSizeDelta.short.shortToken * multiplier;

            if (positionInfo.position.collateralToken() == cache.market.longToken) {
                positionInfo.fees.funding.latestFundingFeeAmountPerSize += nextFundingAmountResult.fundingFeeAmountPerSizeDelta.short.longToken * multiplier;
            } else {
                positionInfo.fees.funding.latestFundingFeeAmountPerSize += nextFundingAmountResult.fundingFeeAmountPerSizeDelta.short.shortToken * multiplier;
            }
        }

        positionInfo.fees.funding = PositionPricingUtils.getFundingFees(
            positionInfo.fees.funding,
            positionInfo.position
        );

        (positionInfo.basePnlUsd, positionInfo.uncappedBasePnlUsd, /* sizeDeltaInTokens */) = PositionUtils.getPositionPnlUsd(
            dataStore,
            cache.market,
            prices,
            positionInfo.position,
            sizeDeltaUsd
        );

        positionInfo.pnlAfterPriceImpactUsd = positionInfo.executionPriceResult.priceImpactUsd + positionInfo.basePnlUsd;

        positionInfo.fees.totalCostAmountExcludingFunding =
            positionInfo.fees.positionFeeAmount
            + positionInfo.fees.borrowing.borrowingFeeAmount
            + positionInfo.fees.ui.uiFeeAmount
            - positionInfo.fees.totalDiscountAmount;

        positionInfo.fees.totalCostAmount =
            positionInfo.fees.totalCostAmountExcludingFunding
            + positionInfo.fees.funding.fundingFeeAmount;

        return positionInfo;
    }
}
