// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../market/MarketStoreUtils.sol";

import "../deposit/DepositStoreUtils.sol";
import "../withdrawal/WithdrawalStoreUtils.sol";
import "../shift/ShiftStoreUtils.sol";

import "../position/Position.sol";
import "../position/PositionUtils.sol";
import "../position/PositionStoreUtils.sol";

import "../market/MarketUtils.sol";
import "../market/Market.sol";

import "./ReaderUtils.sol";
import "./ReaderDepositUtils.sol";
import "./ReaderWithdrawalUtils.sol";
import "./ReaderPositionUtils.sol";

// @title Reader
// @dev Library for read functions
contract Reader {
    using SafeCast for uint256;
    using Position for Position.Props;

    function getMarket(DataStore dataStore, address key) external view returns (Market.Props memory) {
        return MarketStoreUtils.get(dataStore, key);
    }

    function getMarketBySalt(DataStore dataStore, bytes32 salt) external view returns (Market.Props memory) {
        return MarketStoreUtils.getBySalt(dataStore, salt);
    }

    function getDeposit(DataStore dataStore, bytes32 key) external view returns (Deposit.Props memory) {
        return DepositStoreUtils.get(dataStore, key);
    }

    function getWithdrawal(DataStore dataStore, bytes32 key) external view returns (Withdrawal.Props memory) {
        return WithdrawalStoreUtils.get(dataStore, key);
    }

    function getShift(DataStore dataStore, bytes32 key) external view returns (Shift.Props memory) {
        return ShiftStoreUtils.get(dataStore, key);
    }

    function getPosition(DataStore dataStore, bytes32 key) external view returns (Position.Props memory) {
        return PositionStoreUtils.get(dataStore, key);
    }

    function getOrder(DataStore dataStore, bytes32 key) external view returns (Order.Props memory) {
        return ReaderUtils.getOrder(dataStore, key);
    }

    function getPositionPnlUsd(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        bytes32 positionKey,
        uint256 sizeDeltaUsd
    ) external view returns (int256, int256, uint256) {
        Position.Props memory position = PositionStoreUtils.get(dataStore, positionKey);

        return PositionUtils.getPositionPnlUsd(dataStore, market, prices, position, sizeDeltaUsd);
    }

    function getAccountPositions(
        DataStore dataStore,
        address account,
        uint256 start,
        uint256 end
    ) external view returns (Position.Props[] memory) {
        return ReaderPositionUtils.getAccountPositions(dataStore, account, start, end);
    }

    function getPositionInfo(
        DataStore dataStore,
        IReferralStorage referralStorage,
        bytes32 positionKey,
        MarketUtils.MarketPrices memory prices,
        uint256 sizeDeltaUsd,
        address uiFeeReceiver,
        bool usePositionSizeAsSizeDeltaUsd
    ) public view returns (ReaderPositionUtils.PositionInfo memory) {
        return
            ReaderPositionUtils.getPositionInfo(
                dataStore,
                referralStorage,
                positionKey,
                prices,
                sizeDeltaUsd,
                uiFeeReceiver,
                usePositionSizeAsSizeDeltaUsd
            );
    }

    function getPositionInfoList(
        DataStore dataStore,
        IReferralStorage referralStorage,
        bytes32[] memory positionKeys,
        MarketUtils.MarketPrices[] memory prices,
        address uiFeeReceiver
    ) external view returns (ReaderPositionUtils.PositionInfo[] memory) {
        return
            ReaderPositionUtils.getPositionInfoList(
                dataStore,
                referralStorage,
                positionKeys,
                prices,
                uiFeeReceiver
            );
    }

    // `markets` and `marketPrices` should contain perp markets only
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
        return
            ReaderPositionUtils.getAccountPositionInfoList(
                dataStore,
                referralStorage,
                account,
                markets,
                marketPrices,
                uiFeeReceiver,
                start,
                end
            );
    }

    function isPositionLiquidatable(
        DataStore dataStore,
        IReferralStorage referralStorage,
        bytes32 positionKey,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        bool shouldValidateMinCollateralUsd
    ) public view returns (bool, string memory, PositionUtils.IsPositionLiquidatableInfo memory) {
        Position.Props memory position = PositionStoreUtils.get(dataStore, positionKey);

        return
            PositionUtils.isPositionLiquidatable(
                dataStore,
                referralStorage,
                position,
                market,
                prices,
                shouldValidateMinCollateralUsd
            );
    }

    function getAccountOrders(
        DataStore dataStore,
        address account,
        uint256 start,
        uint256 end
    ) external view returns (ReaderUtils.OrderInfo[] memory) {
        return ReaderUtils.getAccountOrders(dataStore, account, start, end);
    }

    function getMarkets(DataStore dataStore, uint256 start, uint256 end) external view returns (Market.Props[] memory) {
        return ReaderUtils.getMarkets(dataStore, start, end);
    }

    function getMarketInfoList(
        DataStore dataStore,
        MarketUtils.MarketPrices[] memory marketPricesList,
        uint256 start,
        uint256 end
    ) external view returns (ReaderUtils.MarketInfo[] memory) {
        return ReaderUtils.getMarketInfoList(dataStore, marketPricesList, start, end);
    }

    function getMarketInfo(
        DataStore dataStore,
        MarketUtils.MarketPrices memory prices,
        address marketKey
    ) public view returns (ReaderUtils.MarketInfo memory) {
        return ReaderUtils.getMarketInfo(dataStore, prices, marketKey);
    }

    function getMarketTokenPrice(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        Price.Props memory longTokenPrice,
        Price.Props memory shortTokenPrice,
        bytes32 pnlFactorType,
        bool maximize
    ) external view returns (int256, MarketPoolValueInfo.Props memory) {
        return
            MarketUtils.getMarketTokenPrice(
                dataStore,
                market,
                indexTokenPrice,
                longTokenPrice,
                shortTokenPrice,
                pnlFactorType,
                maximize
            );
    }

    function getNetPnl(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        bool maximize
    ) external view returns (int256) {
        return MarketUtils.getNetPnl(dataStore, market, indexTokenPrice, maximize);
    }

    function getPnl(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        bool isLong,
        bool maximize
    ) external view returns (int256) {
        return MarketUtils.getPnl(dataStore, market, indexTokenPrice, isLong, maximize);
    }

    function getOpenInterestWithPnl(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        bool isLong,
        bool maximize
    ) external view returns (int256) {
        return MarketUtils.getOpenInterestWithPnl(dataStore, market, indexTokenPrice, isLong, maximize);
    }

    function getPnlToPoolFactor(
        DataStore dataStore,
        address marketAddress,
        MarketUtils.MarketPrices memory prices,
        bool isLong,
        bool maximize
    ) external view returns (int256) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketAddress);
        return MarketUtils.getPnlToPoolFactor(dataStore, market, prices, isLong, maximize);
    }

    function getSwapAmountOut(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        address tokenIn,
        uint256 amountIn,
        address uiFeeReceiver
    ) external view returns (uint256, int256, SwapPricingUtils.SwapFees memory fees) {
        return ReaderPricingUtils.getSwapAmountOut(dataStore, market, prices, tokenIn, amountIn, uiFeeReceiver);
    }

    function getExecutionPrice(
        DataStore dataStore,
        address marketKey,
        Price.Props memory indexTokenPrice,
        uint256 positionSizeInUsd,
        uint256 positionSizeInTokens,
        int256 sizeDeltaUsd,
        bool isLong
    ) external view returns (ReaderPricingUtils.ExecutionPriceResult memory) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketKey);
        return
            ReaderPricingUtils.getExecutionPrice(
                dataStore,
                market,
                indexTokenPrice,
                positionSizeInUsd,
                positionSizeInTokens,
                sizeDeltaUsd,
                isLong
            );
    }

    function getSwapPriceImpact(
        DataStore dataStore,
        address marketKey,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        Price.Props memory tokenInPrice,
        Price.Props memory tokenOutPrice
    ) external view returns (int256, int256, int256) {
        Market.Props memory market = MarketStoreUtils.get(dataStore, marketKey);
        return
            ReaderPricingUtils.getSwapPriceImpact(
                dataStore,
                market,
                tokenIn,
                tokenOut,
                amountIn,
                tokenInPrice,
                tokenOutPrice
            );
    }

    function getAdlState(
        DataStore dataStore,
        address market,
        bool isLong,
        MarketUtils.MarketPrices memory prices
    ) external view returns (uint256, bool, int256, uint256) {
        return ReaderUtils.getAdlState(dataStore, market, isLong, prices);
    }

    function getDepositAmountOut(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        uint256 longTokenAmount,
        uint256 shortTokenAmount,
        address uiFeeReceiver,
        ISwapPricingUtils.SwapPricingType swapPricingType,
        bool includeVirtualInventoryImpact
    ) external view returns (uint256) {
        return
            ReaderDepositUtils.getDepositAmountOut(
                dataStore,
                market,
                prices,
                longTokenAmount,
                shortTokenAmount,
                uiFeeReceiver,
                swapPricingType,
                includeVirtualInventoryImpact
            );
    }

    function getWithdrawalAmountOut(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        uint256 marketTokenAmount,
        address uiFeeReceiver,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external view returns (uint256, uint256) {
        return
            ReaderWithdrawalUtils.getWithdrawalAmountOut(
                dataStore,
                market,
                prices,
                marketTokenAmount,
                uiFeeReceiver,
                swapPricingType
            );
    }
}
