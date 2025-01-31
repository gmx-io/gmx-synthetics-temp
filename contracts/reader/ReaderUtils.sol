// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "../data/Keys.sol";

import "../market/MarketStoreUtils.sol";

import "../position/Position.sol";

import "../order/OrderStoreUtils.sol";

import "../adl/AdlUtils.sol";

import "../market/MarketUtils.sol";
import "../market/Market.sol";

import "./ReaderPositionUtils.sol";

// @title ReaderUtils
// @dev Library for read utils functions
// convers some internal library functions into external functions to reduce
// the Reader contract size
library ReaderUtils {
    using SignedMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Price for Price.Props;
    using Position for Position.Props;
    using Order for Order.Props;

    struct VirtualInventory {
        uint256 virtualPoolAmountForLongToken;
        uint256 virtualPoolAmountForShortToken;
        int256 virtualInventoryForPositions;
    }

    struct MarketInfo {
        Market.Props market;
        uint256 borrowingFactorPerSecondForLongs;
        uint256 borrowingFactorPerSecondForShorts;
        BaseFundingValues baseFunding;
        MarketUtils.GetNextFundingAmountPerSizeResult nextFunding;
        VirtualInventory virtualInventory;
        bool isDisabled;
    }

    struct OrderInfo {
        bytes32 orderKey;
        Order.Props order;
    }

    struct BaseFundingValues {
        MarketUtils.PositionType fundingFeeAmountPerSize;
        MarketUtils.PositionType claimableFundingAmountPerSize;
    }

    function getOrder(DataStore dataStore, bytes32 key) external view returns (Order.Props memory) {
        return OrderStoreUtils.get(dataStore, key);
    }

    function getAccountOrders(
        DataStore dataStore,
        address account,
        uint256 start,
        uint256 end
    ) external view returns (Order.Props[] memory) {
        bytes32[] memory orderKeys = OrderStoreUtils.getAccountOrderKeys(dataStore, account, start, end);
        Order.Props[] memory orders = new Order.Props[](orderKeys.length);
        for (uint256 i; i < orderKeys.length; i++) {
            bytes32 orderKey = orderKeys[i];
            orders[i] = OrderStoreUtils.get(dataStore, orderKey);
        }

        return orders;
    }

    function getBaseFundingValues(DataStore dataStore, Market.Props memory market) public view returns (BaseFundingValues memory) {
        BaseFundingValues memory values;

        values.fundingFeeAmountPerSize.long.longToken = MarketUtils.getFundingFeeAmountPerSize(
            dataStore,
            market.marketToken,
            market.longToken,
            true // isLong
        );

        values.fundingFeeAmountPerSize.long.shortToken = MarketUtils.getFundingFeeAmountPerSize(
            dataStore,
            market.marketToken,
            market.shortToken,
            true // isLong
        );

        values.fundingFeeAmountPerSize.short.longToken = MarketUtils.getFundingFeeAmountPerSize(
            dataStore,
            market.marketToken,
            market.longToken,
            false // isLong
        );

        values.fundingFeeAmountPerSize.short.shortToken = MarketUtils.getFundingFeeAmountPerSize(
            dataStore,
            market.marketToken,
            market.shortToken,
            false // isLong
        );

        values.claimableFundingAmountPerSize.long.longToken = MarketUtils.getClaimableFundingAmountPerSize(
            dataStore,
            market.marketToken,
            market.longToken,
            true // isLong
        );

        values.claimableFundingAmountPerSize.long.shortToken = MarketUtils.getClaimableFundingAmountPerSize(
            dataStore,
            market.marketToken,
            market.shortToken,
            true // isLong
        );

        values.claimableFundingAmountPerSize.short.longToken = MarketUtils.getClaimableFundingAmountPerSize(
            dataStore,
            market.marketToken,
            market.longToken,
            false // isLong
        );

        values.claimableFundingAmountPerSize.short.shortToken = MarketUtils.getClaimableFundingAmountPerSize(
            dataStore,
            market.marketToken,
            market.shortToken,
            false // isLong
        );

        return values;
    }

    function getMarkets(DataStore dataStore, uint256 start, uint256 end) external view returns (Market.Props[] memory) {
        address[] memory marketKeys = MarketStoreUtils.getMarketKeys(dataStore, start, end);
        Market.Props[] memory markets = new Market.Props[](marketKeys.length);
        for (uint256 i; i < marketKeys.length; i++) {
            address marketKey = marketKeys[i];
            Market.Props memory market = MarketStoreUtils.get(dataStore, marketKey);
            markets[i] = market;
        }

        return markets;
    }

    function getMarketInfo(
        DataStore dataStore,
        MarketUtils.MarketPrices memory prices,
        address marketKey
    ) public view returns (MarketInfo memory) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketKey);

        uint256 borrowingFactorPerSecondForLongs = MarketUtils.getBorrowingFactorPerSecond(
            dataStore,
            market,
            prices,
            true
        );

        uint256 borrowingFactorPerSecondForShorts = MarketUtils.getBorrowingFactorPerSecond(
            dataStore,
            market,
            prices,
            false
        );

        BaseFundingValues memory baseFunding = getBaseFundingValues(dataStore, market);

        MarketUtils.GetNextFundingAmountPerSizeResult memory nextFunding = ReaderPositionUtils.getNextFundingAmountPerSize(
            dataStore,
            market,
            prices
        );

        VirtualInventory memory virtualInventory = getVirtualInventory(dataStore, market);

        bool isMarketDisabled = dataStore.getBool(Keys.isMarketDisabledKey(market.marketToken));

        return
            MarketInfo(
                market,
                borrowingFactorPerSecondForLongs,
                borrowingFactorPerSecondForShorts,
                baseFunding,
                nextFunding,
                virtualInventory,
                isMarketDisabled
            );
    }

    function getMarketInfoList(
        DataStore dataStore,
        MarketUtils.MarketPrices[] memory marketPricesList,
        uint256 start,
        uint256 end
    ) external view returns (ReaderUtils.MarketInfo[] memory) {
        address[] memory marketKeys = MarketStoreUtils.getMarketKeys(dataStore, start, end);
        ReaderUtils.MarketInfo[] memory marketInfoList = new ReaderUtils.MarketInfo[](marketKeys.length);
        for (uint256 i; i < marketKeys.length; i++) {
            MarketUtils.MarketPrices memory prices = marketPricesList[i];
            address marketKey = marketKeys[i];
            marketInfoList[i] = getMarketInfo(dataStore, prices, marketKey);
        }

        return marketInfoList;
    }

    function getVirtualInventory(
        DataStore dataStore,
        Market.Props memory market
    ) internal view returns (VirtualInventory memory) {
        (, uint256 virtualPoolAmountForLongToken, uint256 virtualPoolAmountForShortToken) = MarketUtils
            .getVirtualInventoryForSwaps(dataStore, market.marketToken);
        (, int256 virtualInventoryForPositions) = MarketUtils.getVirtualInventoryForPositions(
            dataStore,
            market.indexToken
        );

        return
            VirtualInventory(
                virtualPoolAmountForLongToken,
                virtualPoolAmountForShortToken,
                virtualInventoryForPositions
            );
    }

    function getAdlState(
        DataStore dataStore,
        address market,
        bool isLong,
        MarketUtils.MarketPrices memory prices
    ) external view returns (uint256, bool, int256, uint256) {
        uint256 latestAdlTime = AdlUtils.getLatestAdlTime(dataStore, market, isLong);
        Market.Props memory _market = MarketUtils.getEnabledMarket(dataStore, market);

        (bool shouldEnableAdl, int256 pnlToPoolFactor, uint256 maxPnlFactor) = MarketUtils.isPnlFactorExceeded(
            dataStore,
            _market,
            prices,
            isLong,
            Keys.MAX_PNL_FACTOR_FOR_ADL
        );

        return (latestAdlTime, shouldEnableAdl, pnlToPoolFactor, maxPnlFactor);
    }
}
