// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "../data/Keys.sol";

import "../position/Position.sol";
import "../market/MarketUtils.sol";
import "../market/Market.sol";

import "../pricing/ISwapPricingUtils.sol";
import "../pricing/SwapPricingUtils.sol";

library ReaderWithdrawalUtils {
    using SignedMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;
    using Price for Price.Props;
    using Position for Position.Props;
    using Order for Order.Props;

    struct GetWithdrawalAmountOutCache {
        uint256 poolValue;
        uint256 marketTokensSupply;

        uint256 longTokenPoolAmount;
        uint256 shortTokenPoolAmount;

        uint256 longTokenPoolUsd;
        uint256 shortTokenPoolUsd;

        uint256 totalPoolUsd;

        uint256 marketTokensUsd;

        uint256 longTokenOutputUsd;
        uint256 shortTokenOutputUsd;

        uint256 longTokenOutputAmount;
        uint256 shortTokenOutputAmount;
    }

    function getWithdrawalAmountOut(
        DataStore dataStore,
        Market.Props memory market,
        MarketUtils.MarketPrices memory prices,
        uint256 marketTokenAmount,
        address uiFeeReceiver,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external view returns (uint256, uint256) {
        GetWithdrawalAmountOutCache memory cache;

        MarketPoolValueInfo.Props memory poolValueInfo = MarketUtils.getPoolValueInfo(
            dataStore,
            market,
            prices.indexTokenPrice,
            prices.longTokenPrice,
            prices.shortTokenPrice,
            Keys.MAX_PNL_FACTOR_FOR_WITHDRAWALS,
            false
        );

        if (poolValueInfo.poolValue <= 0) {
            revert Errors.InvalidPoolValueForWithdrawal(poolValueInfo.poolValue);
        }

        cache.poolValue = poolValueInfo.poolValue.toUint256();
        cache.marketTokensSupply = MarketUtils.getMarketTokenSupply(MarketToken(payable(market.marketToken)));

        cache.longTokenPoolAmount = MarketUtils.getPoolAmount(dataStore, market, market.longToken);
        cache.shortTokenPoolAmount = MarketUtils.getPoolAmount(dataStore, market, market.shortToken);

        cache.longTokenPoolUsd = cache.longTokenPoolAmount * prices.longTokenPrice.max;
        cache.shortTokenPoolUsd = cache.shortTokenPoolAmount * prices.shortTokenPrice.max;

        cache.totalPoolUsd = cache.longTokenPoolUsd + cache.shortTokenPoolUsd;

        cache.marketTokensUsd = MarketUtils.marketTokenAmountToUsd(marketTokenAmount, cache.poolValue, cache.marketTokensSupply);

        cache.longTokenOutputUsd = Precision.mulDiv(cache.marketTokensUsd, cache.longTokenPoolUsd, cache.totalPoolUsd);
        cache.shortTokenOutputUsd = Precision.mulDiv(cache.marketTokensUsd, cache.shortTokenPoolUsd, cache.totalPoolUsd);

        cache.longTokenOutputAmount = cache.longTokenOutputUsd / prices.longTokenPrice.max;
        cache.shortTokenOutputAmount = cache.shortTokenOutputUsd / prices.shortTokenPrice.max;

        SwapPricingUtils.SwapFees memory longTokenFees = SwapPricingUtils.getSwapFees(
            dataStore,
            market.marketToken,
            cache.longTokenOutputAmount,
            false, // balanceWasImproved
            uiFeeReceiver,
            swapPricingType
        );

        SwapPricingUtils.SwapFees memory shortTokenFees = SwapPricingUtils.getSwapFees(
            dataStore,
            market.marketToken,
            cache.shortTokenOutputAmount,
            false, // balanceWasImproved
            uiFeeReceiver,
            swapPricingType
        );

        return (
            longTokenFees.amountAfterFees,
            shortTokenFees.amountAfterFees
        );
    }
}
