// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SignedMath.sol";

import "../market/MarketUtils.sol";

import "../utils/Precision.sol";
import "../utils/Calc.sol";

import "./PricingUtils.sol";
import "./ISwapPricingUtils.sol";

// @title SwapPricingUtils
// @dev Library for pricing functions
library SwapPricingUtils {
    using SignedMath for int256;
    using SafeCast for uint256;
    using SafeCast for int256;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    // @dev GetPriceImpactUsdParams struct used in getPriceImpactUsd to
    // avoid stack too deep errors
    // @param dataStore DataStore
    // @param market the market to check
    // @param tokenA the token to check balance for
    // @param tokenB the token to check balance for
    // @param priceForTokenA the price for tokenA
    // @param priceForTokenB the price for tokenB
    // @param usdDeltaForTokenA the USD change in amount of tokenA
    // @param usdDeltaForTokenB the USD change in amount of tokenB
    struct GetPriceImpactUsdParams {
        DataStore dataStore;
        Market.Props market;
        address tokenA;
        address tokenB;
        uint256 priceForTokenA;
        uint256 priceForTokenB;
        int256 usdDeltaForTokenA;
        int256 usdDeltaForTokenB;
        bool includeVirtualInventoryImpact;
    }

    struct EmitSwapInfoParams {
        bytes32 orderKey;
        address market;
        address receiver;
        address tokenIn;
        address tokenOut;
        uint256 tokenInPrice;
        uint256 tokenOutPrice;
        uint256 amountIn;
        uint256 amountInAfterFees;
        uint256 amountOut;
        int256 priceImpactUsd;
        int256 priceImpactAmount;
        int256 tokenInPriceImpactAmount;
    }

    // @dev PoolParams struct to contain pool values
    // @param poolUsdForTokenA the USD value of tokenA in the pool
    // @param poolUsdForTokenB the USD value of tokenB in the pool
    // @param nextPoolUsdForTokenA the next USD value of tokenA in the pool
    // @param nextPoolUsdForTokenB the next USD value of tokenB in the pool
    struct PoolParams {
        uint256 poolUsdForTokenA;
        uint256 poolUsdForTokenB;
        uint256 nextPoolUsdForTokenA;
        uint256 nextPoolUsdForTokenB;
    }

    // @dev SwapFees struct to contain swap fee values
    // @param feeReceiverAmount the fee amount for the fee receiver
    // @param feeAmountForPool the fee amount for the pool
    // @param amountAfterFees the output amount after fees
    struct SwapFees {
        uint256 feeReceiverAmount;
        uint256 feeAmountForPool;
        uint256 amountAfterFees;

        address uiFeeReceiver;
        uint256 uiFeeReceiverFactor;
        uint256 uiFeeAmount;
    }

    // @dev get the price impact in USD
    //
    // note that there will be some difference between the pool amounts used for
    // calculating the price impact and fees vs the actual pool amounts after the
    // swap is done, since the pool amounts will be increased / decreased by an amount
    // after factoring in the calculated price impact and fees
    //
    // since the calculations are based on the real-time prices values of the tokens
    // if a token price increases, the pool will incentivise swapping out more of that token
    // this is useful if prices are ranging, if prices are strongly directional, the pool may
    // be selling tokens as the token price increases
    //
    // @param params GetPriceImpactUsdParams
    //
    // @return the price impact in USD and the balanceWasImproved boolean
    function getPriceImpactUsd(GetPriceImpactUsdParams memory params) external view returns (int256, bool) {
        PoolParams memory poolParams = getNextPoolAmountsUsd(params);

        (int256 priceImpactUsd, bool balanceWasImproved) = _getPriceImpactUsd(params.dataStore, params.market, poolParams);

        // the virtual price impact calculation is skipped if the price impact
        // is positive since the action is helping to balance the pool
        //
        // in case two virtual pools are unbalanced in a different direction
        // e.g. pool0 has more WNT than USDC while pool1 has less WNT
        // than USDT
        // not skipping the virtual price impact calculation would lead to
        // a negative price impact for any trade on either pools and would
        // disincentivise the balancing of pools
        if (priceImpactUsd >= 0) { return (priceImpactUsd, balanceWasImproved); }

        if (!params.includeVirtualInventoryImpact) {
            return (priceImpactUsd, balanceWasImproved);
        }

        // note that the virtual pool for the long token / short token may be different across pools
        // e.g. ETH/USDC, ETH/USDT would have USDC and USDT as the short tokens
        // the short token amount is multiplied by the price of the token in the current pool, e.g. if the swap
        // is for the ETH/USDC pool, the combined USDC and USDT short token amounts is multiplied by the price of
        // USDC to calculate the price impact, this should be reasonable most of the time unless there is a
        // large depeg of one of the tokens, in which case it may be necessary to remove that market from being a virtual
        // market, removal of virtual markets may lead to incorrect virtual token accounting, the feature to correct for
        // this can be added if needed
        (bool hasVirtualInventory, uint256 virtualPoolAmountForLongToken, uint256 virtualPoolAmountForShortToken) = MarketUtils.getVirtualInventoryForSwaps(
            params.dataStore,
            params.market.marketToken
        );

        if (!hasVirtualInventory) {
            return (priceImpactUsd, balanceWasImproved);
        }

        uint256 virtualPoolAmountForTokenA;
        uint256 virtualPoolAmountForTokenB;

        if (params.tokenA == params.market.longToken) {
            virtualPoolAmountForTokenA = virtualPoolAmountForLongToken;
            virtualPoolAmountForTokenB = virtualPoolAmountForShortToken;
        } else {
            virtualPoolAmountForTokenA = virtualPoolAmountForShortToken;
            virtualPoolAmountForTokenB = virtualPoolAmountForLongToken;
        }

        PoolParams memory poolParamsForVirtualInventory = getNextPoolAmountsParams(
            params,
            virtualPoolAmountForTokenA,
            virtualPoolAmountForTokenB
        );

        (int256 priceImpactUsdForVirtualInventory, bool balanceWasImprovedForVirtualInventory) = _getPriceImpactUsd(params.dataStore, params.market, poolParamsForVirtualInventory);

        return priceImpactUsdForVirtualInventory < priceImpactUsd ? (priceImpactUsdForVirtualInventory, balanceWasImprovedForVirtualInventory) : (priceImpactUsd, balanceWasImproved);
    }

    // @dev get the price impact in USD and whether the balance was improved
    // @param dataStore DataStore
    // @param market the trading market
    // @param poolParams PoolParams
    // @return the price impact in USD and the balanceWasImproved boolean
    function _getPriceImpactUsd(DataStore dataStore, Market.Props memory market, PoolParams memory poolParams) internal view returns (int256, bool) {
        uint256 initialDiffUsd = Calc.diff(poolParams.poolUsdForTokenA, poolParams.poolUsdForTokenB);
        uint256 nextDiffUsd = Calc.diff(poolParams.nextPoolUsdForTokenA, poolParams.nextPoolUsdForTokenB);

        // check whether an improvement in balance comes from causing the balance to switch sides
        // for example, if there is $2000 of ETH and $1000 of USDC in the pool
        // adding $1999 USDC into the pool will reduce absolute balance from $1000 to $999 but it does not
        // help rebalance the pool much, the isSameSideRebalance value helps avoid gaming using this case
        bool isSameSideRebalance = (poolParams.poolUsdForTokenA <= poolParams.poolUsdForTokenB) == (poolParams.nextPoolUsdForTokenA <= poolParams.nextPoolUsdForTokenB);
        uint256 impactExponentFactor = dataStore.getUint(Keys.swapImpactExponentFactorKey(market.marketToken));

        bool balanceWasImproved = nextDiffUsd < initialDiffUsd;
        if (isSameSideRebalance) {
            uint256 impactFactor = MarketUtils.getAdjustedSwapImpactFactor(dataStore, market.marketToken, balanceWasImproved);

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
            (uint256 positiveImpactFactor, uint256 negativeImpactFactor) = MarketUtils.getAdjustedSwapImpactFactors(dataStore, market.marketToken);

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

    // @dev get the next pool amounts in USD
    // @param params GetPriceImpactUsdParams
    // @return PoolParams
    function getNextPoolAmountsUsd(
        GetPriceImpactUsdParams memory params
    ) internal view returns (PoolParams memory) {
        uint256 poolAmountForTokenA = MarketUtils.getPoolAmount(params.dataStore, params.market, params.tokenA);
        uint256 poolAmountForTokenB = MarketUtils.getPoolAmount(params.dataStore, params.market, params.tokenB);

        return getNextPoolAmountsParams(
            params,
            poolAmountForTokenA,
            poolAmountForTokenB
        );
    }

    function getNextPoolAmountsParams(
        GetPriceImpactUsdParams memory params,
        uint256 poolAmountForTokenA,
        uint256 poolAmountForTokenB
    ) internal pure returns (PoolParams memory) {
        uint256 poolUsdForTokenA = poolAmountForTokenA * params.priceForTokenA;
        uint256 poolUsdForTokenB = poolAmountForTokenB * params.priceForTokenB;

        if (params.usdDeltaForTokenA < 0 && (-params.usdDeltaForTokenA).toUint256() > poolUsdForTokenA) {
            revert Errors.UsdDeltaExceedsPoolValue(params.usdDeltaForTokenA, poolUsdForTokenA);
        }

        if (params.usdDeltaForTokenB < 0 && (-params.usdDeltaForTokenB).toUint256() > poolUsdForTokenB) {
            revert Errors.UsdDeltaExceedsPoolValue(params.usdDeltaForTokenB, poolUsdForTokenB);
        }

        uint256 nextPoolUsdForTokenA = Calc.sumReturnUint256(poolUsdForTokenA, params.usdDeltaForTokenA);
        uint256 nextPoolUsdForTokenB = Calc.sumReturnUint256(poolUsdForTokenB, params.usdDeltaForTokenB);

        PoolParams memory poolParams = PoolParams(
            poolUsdForTokenA,
            poolUsdForTokenB,
            nextPoolUsdForTokenA,
            nextPoolUsdForTokenB
        );

        return poolParams;
    }

    // @dev get the swap fees
    // @param dataStore DataStore
    // @param marketToken the address of the market token
    // @param amount the total swap fee amount
    function getSwapFees(
        DataStore dataStore,
        address marketToken,
        uint256 amount,
        bool balanceWasImproved,
        address uiFeeReceiver,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) internal view returns (SwapFees memory) {
        SwapFees memory fees;

        // note that since it is possible to incur both positive and negative price impact values
        // and the negative price impact factor may be larger than the positive impact factor
        // it is possible for the balance to be improved overall but for the price impact to still be negative
        // in this case the fee factor for the negative price impact would be charged
        // a user could split the order into two, to incur a smaller fee, reducing the fee through this should not be a large issue
        uint256 feeFactor;

        if (swapPricingType == ISwapPricingUtils.SwapPricingType.Swap) {
            feeFactor = dataStore.getUint(Keys.swapFeeFactorKey(marketToken, balanceWasImproved));
        } else if (swapPricingType == ISwapPricingUtils.SwapPricingType.Shift) {
            // empty branch as feeFactor is already zero
        } else if (swapPricingType == ISwapPricingUtils.SwapPricingType.Atomic) {
            feeFactor = dataStore.getUint(Keys.atomicSwapFeeFactorKey(marketToken));
        } else if (swapPricingType == ISwapPricingUtils.SwapPricingType.Deposit) {
            feeFactor = dataStore.getUint(Keys.depositFeeFactorKey(marketToken, balanceWasImproved));
        } else if (swapPricingType == ISwapPricingUtils.SwapPricingType.Withdrawal) {
            feeFactor = dataStore.getUint(Keys.withdrawalFeeFactorKey(marketToken, balanceWasImproved));
        }

        uint256 swapFeeReceiverFactor = dataStore.getUint(Keys.SWAP_FEE_RECEIVER_FACTOR);

        uint256 feeAmount = Precision.applyFactor(amount, feeFactor);

        fees.feeReceiverAmount = Precision.applyFactor(feeAmount, swapFeeReceiverFactor);
        fees.feeAmountForPool = feeAmount - fees.feeReceiverAmount;

        fees.uiFeeReceiver = uiFeeReceiver;
        fees.uiFeeReceiverFactor = MarketUtils.getUiFeeFactor(dataStore, uiFeeReceiver);
        fees.uiFeeAmount = Precision.applyFactor(amount, fees.uiFeeReceiverFactor);

        fees.amountAfterFees = amount - feeAmount - fees.uiFeeAmount;

        return fees;
    }

    // note that the priceImpactUsd may not be entirely accurate since it is the
    // base calculation and the actual price impact may be capped by the available
    // amount in the swap impact pool
    function emitSwapInfo(
        EventEmitter eventEmitter,
        EmitSwapInfoParams memory params
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "orderKey", params.orderKey);

        eventData.addressItems.initItems(4);
        eventData.addressItems.setItem(0, "market", params.market);
        eventData.addressItems.setItem(1, "receiver", params.receiver);
        eventData.addressItems.setItem(2, "tokenIn", params.tokenIn);
        eventData.addressItems.setItem(3, "tokenOut", params.tokenOut);

        eventData.uintItems.initItems(5);
        eventData.uintItems.setItem(0, "tokenInPrice", params.tokenInPrice);
        eventData.uintItems.setItem(1, "tokenOutPrice", params.tokenOutPrice);
        eventData.uintItems.setItem(2, "amountIn", params.amountIn);
        // note that amountInAfterFees includes negative price impact
        eventData.uintItems.setItem(3, "amountInAfterFees", params.amountInAfterFees);
        eventData.uintItems.setItem(4, "amountOut", params.amountOut);

        eventData.intItems.initItems(3);
        eventData.intItems.setItem(0, "priceImpactUsd", params.priceImpactUsd);
        eventData.intItems.setItem(1, "priceImpactAmount", params.priceImpactAmount);
        eventData.intItems.setItem(2, "tokenInPriceImpactAmount", params.tokenInPriceImpactAmount);

        eventEmitter.emitEventLog1(
            "SwapInfo",
            Cast.toBytes32(params.market),
            eventData
        );
    }

    function emitSwapFeesCollected(
        EventEmitter eventEmitter,
        bytes32 tradeKey,
        address market,
        address token,
        uint256 tokenPrice,
        bytes32 swapFeeType,
        SwapFees memory fees
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(2);
        eventData.bytes32Items.setItem(0, "tradeKey", tradeKey);
        eventData.bytes32Items.setItem(1, "swapFeeType", swapFeeType);

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "uiFeeReceiver", fees.uiFeeReceiver);
        eventData.addressItems.setItem(1, "market", market);
        eventData.addressItems.setItem(2, "token", token);

        eventData.uintItems.initItems(6);
        eventData.uintItems.setItem(0, "tokenPrice", tokenPrice);
        eventData.uintItems.setItem(1, "feeReceiverAmount", fees.feeReceiverAmount);
        eventData.uintItems.setItem(2, "feeAmountForPool", fees.feeAmountForPool);
        eventData.uintItems.setItem(3, "amountAfterFees", fees.amountAfterFees);
        eventData.uintItems.setItem(4, "uiFeeReceiverFactor", fees.uiFeeReceiverFactor);
        eventData.uintItems.setItem(5, "uiFeeAmount", fees.uiFeeAmount);

        eventEmitter.emitEventLog1(
            "SwapFeesCollected",
            Cast.toBytes32(market),
            eventData
        );
    }
}
