// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "../position/Position.sol";
import "../position/PositionUtils.sol";
import "../market/MarketUtils.sol";
import "../market/Market.sol";

// @title ReaderPricingUtils
library ReaderPricingUtils {
    using SignedMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Price for Price.Props;
    using Position for Position.Props;
    using Order for Order.Props;

    struct ExecutionPriceResult {
        int256 priceImpactUsd;
        uint256 executionPrice;
        bool balanceWasImproved;
    }

    struct PositionInfo {
        Position.Props position;
        PositionPricingUtils.PositionFees fees;
        ExecutionPriceResult executionPriceResult;
        int256 basePnlUsd;
        int256 pnlAfterPriceImpactUsd;
    }

    struct GetPositionInfoCache {
        Market.Props market;
        Price.Props collateralTokenPrice;
        uint256 pendingBorrowingFeeUsd;
        int256 latestLongTokenFundingAmountPerSize;
        int256 latestShortTokenFundingAmountPerSize;
    }

    // returns amountOut, price impact, fees
    function getSwapAmountOut(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        address tokenIn,
        uint256 amountIn,
        address uiFeeReceiver
    ) external view returns (uint256, int256, SwapPricingUtils.SwapFees memory) {
        SwapUtils.SwapCache memory cache;

        if (tokenIn != market.longToken && tokenIn != market.shortToken) {
            revert Errors.InvalidTokenIn(tokenIn, market.marketToken);
        }

        MarketUtils.validateSwapMarket(dataStore, market);

        cache.tokenOut = MarketUtils.getOppositeToken(tokenIn, market);
        cache.tokenInPrice = MarketUtils.getCachedTokenPrice(tokenIn, market, prices);
        cache.tokenOutPrice = MarketUtils.getCachedTokenPrice(cache.tokenOut, market, prices);

        (int256 priceImpactUsd, bool balanceWasImproved) = SwapPricingUtils.getPriceImpactUsd(
            SwapPricingUtils.GetPriceImpactUsdParams(
                dataStore,
                market,
                tokenIn,
                cache.tokenOut,
                cache.tokenInPrice.midPrice(),
                cache.tokenOutPrice.midPrice(),
                (amountIn * cache.tokenInPrice.midPrice()).toInt256(),
                -(amountIn * cache.tokenInPrice.midPrice()).toInt256(),
                true // includeVirtualInventoryImpact
            )
        );

        SwapPricingUtils.SwapFees memory fees = SwapPricingUtils.getSwapFees(
            dataStore,
            market.marketToken,
            amountIn,
            balanceWasImproved,
            uiFeeReceiver,
            ISwapPricingUtils.SwapPricingType.Swap
        );

        int256 impactAmount;

        if (priceImpactUsd > 0) {
            // when there is a positive price impact factor, additional tokens from the swap impact pool
            // are withdrawn for the user
            // for example, if 50,000 USDC is swapped out and there is a positive price impact
            // an additional 100 USDC may be sent to the user
            // the swap impact pool is decreased by the used amount

            cache.amountIn = fees.amountAfterFees;

            (impactAmount, cache.cappedDiffUsd) = MarketUtils.getSwapImpactAmountWithCap(
                dataStore,
                market.marketToken,
                cache.tokenOut,
                cache.tokenOutPrice,
                priceImpactUsd
            );

            if (cache.cappedDiffUsd != 0) {
                (cache.tokenInPriceImpactAmount, /* uint256 cappedDiffUsd */) = MarketUtils.getSwapImpactAmountWithCap(
                    dataStore,
                    market.marketToken,
                    tokenIn,
                    cache.tokenInPrice,
                    cache.cappedDiffUsd.toInt256()
                );

                // this additional amountIn is already in the Market
                // it is subtracted from the swap impact pool amount
                // and the market pool amount is increased by the updated
                // amountIn below
                cache.amountIn += cache.tokenInPriceImpactAmount.toUint256();
            }

            // round amountOut down
            cache.amountOut = cache.amountIn * cache.tokenInPrice.min / cache.tokenOutPrice.max;
            cache.poolAmountOut = cache.amountOut;

            cache.amountOut += impactAmount.toUint256();
        } else {
            // when there is a negative price impact factor,
            // less of the input amount is sent to the pool
            // for example, if 10 ETH is swapped in and there is a negative price impact
            // only 9.995 ETH may be swapped in
            // the remaining 0.005 ETH will be stored in the swap impact pool

            (impactAmount, /* uint256 cappedDiffUsd */) = MarketUtils.getSwapImpactAmountWithCap(
                dataStore,
                market.marketToken,
                tokenIn,
                cache.tokenInPrice,
                priceImpactUsd
            );

            cache.amountIn = fees.amountAfterFees - (-impactAmount).toUint256();
            cache.amountOut = cache.amountIn * cache.tokenInPrice.min / cache.tokenOutPrice.max;
            cache.poolAmountOut = cache.amountOut;
        }

        return (cache.amountOut, impactAmount, fees);
    }

    function getExecutionPrice(
        DataStore dataStore,
        Market.Props memory market,
        Price.Props memory indexTokenPrice,
        uint256 positionSizeInUsd,
        uint256 positionSizeInTokens,
        int256 sizeDeltaUsd,
        bool isLong
    ) external view returns (ExecutionPriceResult memory) {
        PositionUtils.UpdatePositionParams memory params;

        params.contracts.dataStore = dataStore;
        params.market = market;

        params.order.setSizeDeltaUsd(sizeDeltaUsd.abs());
        params.order.setIsLong(isLong);

        bool isIncrease = sizeDeltaUsd > 0;
        bool shouldExecutionPriceBeSmaller = isIncrease ? isLong : !isLong;
        params.order.setAcceptablePrice(shouldExecutionPriceBeSmaller ? type(uint256).max : 0);

        params.position.setSizeInUsd(positionSizeInUsd);
        params.position.setSizeInTokens(positionSizeInTokens);
        params.position.setIsLong(isLong);

        ExecutionPriceResult memory result;

        if (sizeDeltaUsd > 0) {
            (result.priceImpactUsd, /* priceImpactAmount */, /* sizeDeltaInTokens */, result.executionPrice, result.balanceWasImproved) = PositionUtils.getExecutionPriceForIncrease(
                params,
                indexTokenPrice
            );
        } else {
             (result.priceImpactUsd, result.executionPrice, result.balanceWasImproved) = PositionUtils.getExecutionPriceForDecrease(
                params,
                indexTokenPrice
            );
        }

        return result;
    }

    function getSwapPriceImpact(
        DataStore dataStore,
        Market.Props memory market,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        Price.Props memory tokenInPrice,
        Price.Props memory tokenOutPrice
    ) external view returns (int256 priceImpactUsdBeforeCap, int256 priceImpactAmount, int256 tokenInPriceImpactAmount) {
        (priceImpactUsdBeforeCap, ) = SwapPricingUtils.getPriceImpactUsd(
            SwapPricingUtils.GetPriceImpactUsdParams(
                dataStore,
                market,
                tokenIn,
                tokenOut,
                tokenInPrice.midPrice(),
                tokenOutPrice.midPrice(),
                (amountIn * tokenInPrice.midPrice()).toInt256(),
                -(amountIn * tokenInPrice.midPrice()).toInt256(),
                true // includeVirtualInventoryImpact
            )
        );

        if (priceImpactUsdBeforeCap > 0) {
            uint256 cappedDiffUsd;
            (priceImpactAmount, cappedDiffUsd) = MarketUtils.getSwapImpactAmountWithCap(
                dataStore,
                market.marketToken,
                tokenOut,
                tokenOutPrice,
                priceImpactUsdBeforeCap
            );

            if (cappedDiffUsd != 0) {
                (tokenInPriceImpactAmount, /* uint256 cappedDiffUsd */) = MarketUtils.getSwapImpactAmountWithCap(
                    dataStore,
                    market.marketToken,
                    tokenIn,
                    tokenInPrice,
                    cappedDiffUsd.toInt256()
                );
            }
        } else {
            (priceImpactAmount, /* uint256 cappedDiffUsd */) = MarketUtils.getSwapImpactAmountWithCap(
                dataStore,
                market.marketToken,
                tokenIn,
                tokenInPrice,
                priceImpactUsdBeforeCap
            );
        }

        return (priceImpactUsdBeforeCap, priceImpactAmount, tokenInPriceImpactAmount);
    }
}
