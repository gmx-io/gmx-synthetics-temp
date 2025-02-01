// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "../oracle/Oracle.sol";
import "../pricing/PositionPricingUtils.sol";

import "./Position.sol";
import "./PositionEventUtils.sol";
import "./PositionUtils.sol";
import "../order/BaseOrderUtils.sol";
import "../order/OrderEventUtils.sol";
import "../utils/Precision.sol";

import "./DecreasePositionSwapUtils.sol";

// @title DecreasePositionCollateralUtils
// @dev Library for functions to help with the calculations when decreasing a position
library DecreasePositionCollateralUtils {
    using SafeCast for uint256;
    using SafeCast for int256;

    using Position for Position.Props;
    using Order for Order.Props;
    using Price for Price.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    struct ProcessCollateralCache {
        bool isInsolventCloseAllowed;
        bool wasSwapped;
        uint256 swapOutputAmount;
        PayForCostResult result;
        int256 totalImpactUsd;
        bool balanceWasImproved;
    }

    struct PayForCostResult {
        uint256 amountPaidInCollateralToken;
        uint256 amountPaidInSecondaryOutputToken;
        uint256 remainingCostUsd;
    }

    // @dev handle the collateral changes of the position
    // @param params PositionUtils.UpdatePositionParams
    // @param cache DecreasePositionCache
    // @return (PositionUtils.DecreasePositionCollateralValues, PositionPricingUtils.PositionFees)
    function processCollateral(
        PositionUtils.UpdatePositionParams memory params,
        PositionUtils.DecreasePositionCache memory cache
    ) external returns (
        PositionUtils.DecreasePositionCollateralValues memory,
        PositionPricingUtils.PositionFees memory
    ) {
        ProcessCollateralCache memory collateralCache;
        PositionUtils.DecreasePositionCollateralValues memory values;

        values.output.outputToken = params.position.collateralToken();
        values.output.secondaryOutputToken = cache.pnlToken;

        // only allow insolvent closing if it is a liquidation or ADL order
        // isInsolventCloseAllowed is used in handleEarlyReturn to determine
        // whether the txn should revert if the remainingCostUsd is below zero
        //
        // for isInsolventCloseAllowed to be true, the sizeDeltaUsd must equal
        // the position size, otherwise there may be pending positive pnl that
        // could be used to pay for fees and the position would be undercharged
        // if the position is not fully closed
        //
        // for ADLs it may be possible that a position needs to be closed by a larger
        // size to fully pay for fees, but closing by that larger size could cause a PnlOvercorrected
        // error to be thrown in AdlHandler, this case should be rare
        collateralCache.isInsolventCloseAllowed =
            params.order.sizeDeltaUsd() == params.position.sizeInUsd() &&
            (
                BaseOrderUtils.isLiquidationOrder(params.order.orderType()) ||
                params.secondaryOrderType == Order.SecondaryOrderType.Adl
            );

        // in case price impact is too high it is capped and the difference is made to be claimable
        // the execution price is based on the capped price impact so it may be a better price than what it should be
        // priceImpactDiffUsd is the difference between the maximum price impact and the originally calculated price impact
        // e.g. if the originally calculated price impact is -$100, but the capped price impact is -$80
        // then priceImpactDiffUsd would be $20
        // priceImpactUsd amount charged upfront, capped by impact pool and max positive factor; priceImpactDiffUsd amount claimable later
        (values.priceImpactUsd, values.executionPrice, collateralCache.balanceWasImproved) = PositionUtils.getExecutionPriceForDecrease(params, cache.prices.indexTokenPrice);

        // the totalPositionPnl is calculated based on the current indexTokenPrice instead of the executionPrice
        // since the executionPrice factors in price impact which should be accounted for separately
        // the sizeDeltaInTokens is calculated as position.sizeInTokens() * sizeDeltaUsd / position.sizeInUsd()
        // the basePnlUsd is the pnl to be realized, and is calculated as:
        // totalPositionPnl * sizeDeltaInTokens / position.sizeInTokens()
        (values.basePnlUsd, values.uncappedBasePnlUsd, values.sizeDeltaInTokens) = PositionUtils.getPositionPnlUsd(
            params.contracts.dataStore,
            params.market,
            cache.prices,
            params.position,
            params.order.sizeDeltaUsd()
        );

        PositionPricingUtils.GetPositionFeesParams memory getPositionFeesParams = PositionPricingUtils.GetPositionFeesParams(
            params.contracts.dataStore, // dataStore
            params.contracts.referralStorage, // referralStorage
            params.position, // position
            cache.collateralTokenPrice, // collateralTokenPrice
            collateralCache.balanceWasImproved, // balanceWasImproved
            params.market.longToken, // longToken
            params.market.shortToken, // shortToken
            params.order.sizeDeltaUsd(), // sizeDeltaUsd
            params.order.uiFeeReceiver(), // uiFeeReceiver
            BaseOrderUtils.isLiquidationOrder(params.order.orderType()) // isLiquidation
        );

        // if the pnl is positive, deduct the pnl amount from the pool
        if (values.basePnlUsd > 0) {
            // use pnlTokenPrice.max to minimize the tokens paid out
            uint256 deductionAmountForPool = values.basePnlUsd.toUint256() / cache.pnlTokenPrice.max;

            MarketUtils.applyDeltaToPoolAmount(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.market,
                cache.pnlToken,
                -deductionAmountForPool.toInt256()
            );

            if (values.output.outputToken == cache.pnlToken) {
                values.output.outputAmount += deductionAmountForPool;
            } else {
                values.output.secondaryOutputAmount += deductionAmountForPool;
            }
        }

        // order size has been enforced to be less or equal than position size (i.e. sizeDeltaUsd <= sizeInUsd)
        (values.proportionalPendingImpactAmount, values.proportionalImpactPendingUsd) = _getProportionalImpactPendingValues(
            params.position.sizeInUsd(),
            params.position.pendingImpactAmount(),
            params.order.sizeDeltaUsd(),
            cache.prices.indexTokenPrice
        );

        collateralCache.totalImpactUsd = values.proportionalImpactPendingUsd + values.priceImpactUsd;

        if (collateralCache.totalImpactUsd < 0) {
            uint256 maxPriceImpactFactor = MarketUtils.getMaxPositionImpactFactor(
                params.contracts.dataStore,
                params.market.marketToken,
                false
            );

            // convert the max price impact to the min negative value
            // e.g. if sizeDeltaUsd is 10,000 and maxPriceImpactFactor is 2%
            // then minPriceImpactUsd = -200
            int256 minPriceImpactUsd = -Precision.applyFactor(params.order.sizeDeltaUsd(), maxPriceImpactFactor).toInt256();

            // cap totalImpactUsd to the min negative value and store the difference in priceImpactDiffUsd
            // e.g. if totalImpactUsd is -500 and minPriceImpactUsd is -200
            // then set priceImpactDiffUsd to -200 - -500 = 300
            // set totalImpactUsd to -200
            if (collateralCache.totalImpactUsd < minPriceImpactUsd) {
                values.priceImpactDiffUsd = (minPriceImpactUsd - collateralCache.totalImpactUsd).toUint256();
                collateralCache.totalImpactUsd = minPriceImpactUsd;
            }
        }

        // cap the positive totalImpactUsd by the available amount in the position impact pool
        collateralCache.totalImpactUsd = MarketUtils.capPositiveImpactUsdByPositionImpactPool(
            params.contracts.dataStore,
            params.market.marketToken,
            cache.prices.indexTokenPrice,
            collateralCache.totalImpactUsd
        );

        if (collateralCache.totalImpactUsd > 0) {
            uint256 deductionAmountForImpactPool = Calc.roundUpDivision(collateralCache.totalImpactUsd.toUint256(), cache.prices.indexTokenPrice.min);

            MarketUtils.applyDeltaToPositionImpactPool(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.market.marketToken,
                -deductionAmountForImpactPool.toInt256()
            );

            // use pnlTokenPrice.max to minimize the payout from the pool
            // some impact pool value may be transferred to the market token pool if there is a
            // large spread between min and max prices
            // since if there is a positive priceImpactUsd, the impact pool would be reduced using indexTokenPrice.min to
            // maximize the deduction value, while the market token pool is reduced using the pnlTokenPrice.max to minimize
            // the deduction value
            // the pool value is calculated by subtracting the worth of the tokens in the position impact pool
            // so this transfer of value would increase the price of the market token
            uint256 deductionAmountForPool = collateralCache.totalImpactUsd.toUint256() / cache.pnlTokenPrice.max;

            MarketUtils.applyDeltaToPoolAmount(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.market,
                cache.pnlToken,
                -deductionAmountForPool.toInt256()
            );

            if (values.output.outputToken == cache.pnlToken) {
                values.output.outputAmount += deductionAmountForPool;
            } else {
                values.output.secondaryOutputAmount += deductionAmountForPool;
            }
        }

        // swap profit to the collateral token
        // if the decreasePositionSwapType was set to NoSwap or if the swap fails due
        // to insufficient liquidity or other reasons then it is possible that
        // the profit remains in a different token from the collateral token
        (collateralCache.wasSwapped, collateralCache.swapOutputAmount) = DecreasePositionSwapUtils.swapProfitToCollateralToken(
            params,
            cache.pnlToken,
            values.output.secondaryOutputAmount
        );

        // if the swap was successful the profit should have been swapped
        // to the collateral token
        if (collateralCache.wasSwapped) {
            values.output.outputAmount += collateralCache.swapOutputAmount;
            values.output.secondaryOutputAmount = 0;
        }

        values.remainingCollateralAmount = params.position.collateralAmount();

        PositionPricingUtils.PositionFees memory fees = PositionPricingUtils.getPositionFees(
            getPositionFeesParams
        );

        // pay for funding fees
        (values, collateralCache.result) = payForCost(
            params,
            values,
            cache.prices,
            cache.collateralTokenPrice,
            // use collateralTokenPrice.min because the payForCost
            // will divide the USD value by the price.min as well
            fees.funding.fundingFeeAmount * cache.collateralTokenPrice.min
        );

        if (collateralCache.result.amountPaidInSecondaryOutputToken > 0) {
            address holdingAddress = params.contracts.dataStore.getAddress(Keys.HOLDING_ADDRESS);
            if (holdingAddress == address(0)) {
                revert Errors.EmptyHoldingAddress();
            }

            // send the funding fee amount to the holding address
            // this funding fee amount should be swapped to the required token
            // and the resulting tokens should be deposited back into the pool
            MarketUtils.incrementClaimableCollateralAmount(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.market.marketToken,
                values.output.secondaryOutputToken,
                holdingAddress,
                collateralCache.result.amountPaidInSecondaryOutputToken
            );
        }

        if (collateralCache.result.amountPaidInCollateralToken < fees.funding.fundingFeeAmount) {
            // the case where this is insufficient collateral to pay funding fees
            // should be rare, and the difference should be small
            // in case it happens, the pool should be topped up with the required amount using
            // the claimable amount sent to the holding address, an insurance fund, or similar mechanism
            PositionEventUtils.emitInsufficientFundingFeePayment(
                params.contracts.eventEmitter,
                params.market.marketToken,
                params.position.collateralToken(),
                fees.funding.fundingFeeAmount,
                collateralCache.result.amountPaidInCollateralToken,
                collateralCache.result.amountPaidInSecondaryOutputToken
            );
        }

        if (collateralCache.result.remainingCostUsd > 0) {
            return handleEarlyReturn(
                params,
                values,
                fees,
                collateralCache,
                "funding"
            );
        }

        // pay for negative pnl
        if (values.basePnlUsd < 0) {
            (values, collateralCache.result) = payForCost(
                params,
                values,
                cache.prices,
                cache.collateralTokenPrice,
                (-values.basePnlUsd).toUint256()
            );

            if (collateralCache.result.amountPaidInCollateralToken > 0) {
                MarketUtils.applyDeltaToPoolAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market,
                    params.position.collateralToken(),
                    collateralCache.result.amountPaidInCollateralToken.toInt256()
                );
            }

            if (collateralCache.result.amountPaidInSecondaryOutputToken > 0) {
                MarketUtils.applyDeltaToPoolAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market,
                    values.output.secondaryOutputToken,
                    collateralCache.result.amountPaidInSecondaryOutputToken.toInt256()
                );
            }

            if (collateralCache.result.remainingCostUsd > 0) {
                return handleEarlyReturn(
                    params,
                    values,
                    fees,
                    collateralCache,
                    "pnl"
                );
            }
        }

        // pay for fees
        (values, collateralCache.result) = payForCost(
            params,
            values,
            cache.prices,
            cache.collateralTokenPrice,
            // use collateralTokenPrice.min because the payForCost
            // will divide the USD value by the price.min as well
            fees.totalCostAmountExcludingFunding * cache.collateralTokenPrice.min
        );

        // if fees were fully paid in the collateral token, update the pool and claimable fee amounts
        if (collateralCache.result.remainingCostUsd == 0 && collateralCache.result.amountPaidInSecondaryOutputToken == 0) {
            // there may be a large amount of borrowing fees that could have been accumulated
            // these fees could cause the pool to become unbalanced, price impact is not paid for causing
            // this imbalance
            // the swap impact pool should be built up so that it can be used to pay for positive price impact
            // for re-balancing to help handle this case
            MarketUtils.applyDeltaToPoolAmount(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.market,
                params.position.collateralToken(),
                fees.feeAmountForPool.toInt256()
            );

            FeeUtils.incrementClaimableFeeAmount(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.market.marketToken,
                params.position.collateralToken(),
                fees.feeReceiverAmount,
                Keys.POSITION_FEE_TYPE
            );

            FeeUtils.incrementClaimableUiFeeAmount(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.order.uiFeeReceiver(),
                params.market.marketToken,
                params.position.collateralToken(),
                fees.ui.uiFeeAmount,
                Keys.UI_POSITION_FEE_TYPE
            );
        } else {
            // the fees are expected to be paid in the collateral token
            // if there are insufficient funds to pay for fees entirely in the collateral token
            // then credit the fee amount entirely to the pool
            if (collateralCache.result.amountPaidInCollateralToken > 0) {
                MarketUtils.applyDeltaToPoolAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market,
                    params.position.collateralToken(),
                    collateralCache.result.amountPaidInCollateralToken.toInt256()
                );
            }

            if (collateralCache.result.amountPaidInSecondaryOutputToken > 0) {
                MarketUtils.applyDeltaToPoolAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market,
                    values.output.secondaryOutputToken,
                    collateralCache.result.amountPaidInSecondaryOutputToken.toInt256()
                );
            }

            // empty the fees since the amount was entirely paid to the pool instead of for fees
            // it is possible for the txn execution to still complete even in this case
            // as long as the remainingCostUsd is still zero
            fees = getEmptyFees(fees);
        }

        if (collateralCache.result.remainingCostUsd > 0) {
            return handleEarlyReturn(
                params,
                values,
                fees,
                collateralCache,
                "fees"
            );
        }

        // pay for negative price impact
        if (collateralCache.totalImpactUsd < 0) {
            (values, collateralCache.result) = payForCost(
                params,
                values,
                cache.prices,
                cache.collateralTokenPrice,
                (-collateralCache.totalImpactUsd).toUint256()
            );

            if (collateralCache.result.amountPaidInCollateralToken > 0) {
                MarketUtils.applyDeltaToPoolAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market,
                    params.position.collateralToken(),
                    collateralCache.result.amountPaidInCollateralToken.toInt256()
                );

                MarketUtils.applyDeltaToPositionImpactPool(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market.marketToken,
                    (collateralCache.result.amountPaidInCollateralToken * cache.collateralTokenPrice.min / cache.prices.indexTokenPrice.max).toInt256()
                );
            }

            if (collateralCache.result.amountPaidInSecondaryOutputToken > 0) {
                MarketUtils.applyDeltaToPoolAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market,
                    values.output.secondaryOutputToken,
                    collateralCache.result.amountPaidInSecondaryOutputToken.toInt256()
                );

                MarketUtils.applyDeltaToPositionImpactPool(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market.marketToken,
                    (collateralCache.result.amountPaidInSecondaryOutputToken * cache.pnlTokenPrice.min / cache.prices.indexTokenPrice.max).toInt256()
                );
            }

            if (collateralCache.result.remainingCostUsd > 0) {
                return handleEarlyReturn(
                    params,
                    values,
                    fees,
                    collateralCache,
                    "impact"
                );
            }
        }

        // pay for price impact diff
        if (values.priceImpactDiffUsd > 0) {
            (values, collateralCache.result) = payForCost(
                params,
                values,
                cache.prices,
                cache.collateralTokenPrice,
                values.priceImpactDiffUsd
            );

            if (collateralCache.result.amountPaidInCollateralToken > 0) {
                MarketUtils.incrementClaimableCollateralAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market.marketToken,
                    params.position.collateralToken(),
                    params.order.account(),
                    collateralCache.result.amountPaidInCollateralToken
                );
            }

            if (collateralCache.result.amountPaidInSecondaryOutputToken > 0) {
                MarketUtils.incrementClaimableCollateralAmount(
                    params.contracts.dataStore,
                    params.contracts.eventEmitter,
                    params.market.marketToken,
                    values.output.secondaryOutputToken,
                    params.order.account(),
                    collateralCache.result.amountPaidInSecondaryOutputToken
                );
            }

            if (collateralCache.result.remainingCostUsd > 0) {
                return handleEarlyReturn(
                    params,
                    values,
                    fees,
                    collateralCache,
                    "diff"
                );
            }
        }

        // the priceImpactDiffUsd has been deducted from the output amount or the position's collateral
        // to reduce the chance that the position's collateral is reduced by an unexpected amount, adjust the
        // initialCollateralDeltaAmount by the priceImpactDiffAmount
        // this would also help to prevent the position's leverage from being unexpectedly increased
        //
        // note that this calculation may not be entirely accurate since it is possible that the priceImpactDiffUsd
        // could have been paid with one of or a combination of collateral / outputAmount / secondaryOutputAmount
        if (params.order.initialCollateralDeltaAmount() > 0 && values.priceImpactDiffUsd > 0) {
            uint256 initialCollateralDeltaAmount = params.order.initialCollateralDeltaAmount();

            uint256 priceImpactDiffAmount = values.priceImpactDiffUsd / cache.collateralTokenPrice.min;
            if (initialCollateralDeltaAmount > priceImpactDiffAmount) {
                params.order.setInitialCollateralDeltaAmount(initialCollateralDeltaAmount - priceImpactDiffAmount);
            } else {
                params.order.setInitialCollateralDeltaAmount(0);
            }

            OrderEventUtils.emitOrderCollateralDeltaAmountAutoUpdated(
                params.contracts.eventEmitter,
                params.orderKey,
                initialCollateralDeltaAmount, // collateralDeltaAmount
                params.order.initialCollateralDeltaAmount() // nextCollateralDeltaAmount
            );
        }

        // cap the withdrawable amount to the remainingCollateralAmount
        if (params.order.initialCollateralDeltaAmount() > values.remainingCollateralAmount) {
            OrderEventUtils.emitOrderCollateralDeltaAmountAutoUpdated(
                params.contracts.eventEmitter,
                params.orderKey,
                params.order.initialCollateralDeltaAmount(), // collateralDeltaAmount
                values.remainingCollateralAmount // nextCollateralDeltaAmount
            );

            params.order.setInitialCollateralDeltaAmount(values.remainingCollateralAmount);
        }

        if (params.order.initialCollateralDeltaAmount() > 0) {
            values.remainingCollateralAmount -= params.order.initialCollateralDeltaAmount();
            values.output.outputAmount += params.order.initialCollateralDeltaAmount();
        }

        return (values, fees);
    }

    function payForCost(
        PositionUtils.UpdatePositionParams memory params,
        PositionUtils.DecreasePositionCollateralValues memory values,
        MarketUtils.MarketPrices memory prices,
        Price.Props memory collateralTokenPrice,
        uint256 costUsd
    ) internal pure returns (PositionUtils.DecreasePositionCollateralValues memory, PayForCostResult memory) {
        PayForCostResult memory result;

        if (costUsd == 0) { return (values, result); }

        uint256 remainingCostInOutputToken = Calc.roundUpDivision(costUsd, collateralTokenPrice.min);

        if (values.output.outputAmount > 0) {
            if (values.output.outputAmount > remainingCostInOutputToken) {
                result.amountPaidInCollateralToken += remainingCostInOutputToken;
                values.output.outputAmount -= remainingCostInOutputToken;
                remainingCostInOutputToken = 0;
            } else {
                result.amountPaidInCollateralToken += values.output.outputAmount;
                remainingCostInOutputToken -= values.output.outputAmount;
                values.output.outputAmount = 0;
            }
        }

        if (remainingCostInOutputToken == 0) { return (values, result); }

        if (values.remainingCollateralAmount > 0) {
            if (values.remainingCollateralAmount > remainingCostInOutputToken) {
                result.amountPaidInCollateralToken += remainingCostInOutputToken;
                values.remainingCollateralAmount -= remainingCostInOutputToken;
                remainingCostInOutputToken = 0;
            } else {
                result.amountPaidInCollateralToken += values.remainingCollateralAmount;
                remainingCostInOutputToken -= values.remainingCollateralAmount;
                values.remainingCollateralAmount = 0;
            }
        }

        if (remainingCostInOutputToken == 0) { return (values, result); }

        Price.Props memory secondaryOutputTokenPrice = MarketUtils.getCachedTokenPrice(values.output.secondaryOutputToken, params.market, prices);

        uint256 remainingCostInSecondaryOutputToken = remainingCostInOutputToken * collateralTokenPrice.min / secondaryOutputTokenPrice.min;

        if (values.output.secondaryOutputAmount > 0) {
            if (values.output.secondaryOutputAmount > remainingCostInSecondaryOutputToken) {
                result.amountPaidInSecondaryOutputToken += remainingCostInSecondaryOutputToken;
                values.output.secondaryOutputAmount -= remainingCostInSecondaryOutputToken;
                remainingCostInSecondaryOutputToken = 0;
            } else {
                result.amountPaidInSecondaryOutputToken += values.output.secondaryOutputAmount;
                remainingCostInSecondaryOutputToken -= values.output.secondaryOutputAmount;
                values.output.secondaryOutputAmount = 0;
            }
        }

        result.remainingCostUsd = remainingCostInSecondaryOutputToken * secondaryOutputTokenPrice.min;

        return (values, result);
    }

    function handleEarlyReturn(
        PositionUtils.UpdatePositionParams memory params,
        PositionUtils.DecreasePositionCollateralValues memory values,
        PositionPricingUtils.PositionFees memory fees,
        ProcessCollateralCache memory collateralCache,
        string memory step
    ) internal returns (PositionUtils.DecreasePositionCollateralValues memory, PositionPricingUtils.PositionFees memory) {
        if (!collateralCache.isInsolventCloseAllowed) {
            revert Errors.InsufficientFundsToPayForCosts(collateralCache.result.remainingCostUsd, step);
        }

        PositionEventUtils.emitPositionFeesInfo(
            params.contracts.eventEmitter,
            params.orderKey,
            params.positionKey,
            params.market.marketToken,
            params.position.collateralToken(),
            params.order.sizeDeltaUsd(),
            false, // isIncrease
            fees
        );

        PositionEventUtils.emitInsolventClose(
            params.contracts.eventEmitter,
            params.orderKey,
            params.position.collateralAmount(),
            values.basePnlUsd,
            collateralCache.result.remainingCostUsd,
            step
        );

        return (values, getEmptyFees(fees));
    }

    function getEmptyFees(
        PositionPricingUtils.PositionFees memory fees
    ) internal pure returns (PositionPricingUtils.PositionFees memory) {
        PositionPricingUtils.PositionReferralFees memory referral = PositionPricingUtils.PositionReferralFees({
            referralCode: bytes32(0),
            affiliate: address(0),
            trader: address(0),
            totalRebateFactor: 0,
            affiliateRewardFactor: 0,
            adjustedAffiliateRewardFactor: 0,
            traderDiscountFactor: 0,
            totalRebateAmount: 0,
            traderDiscountAmount: 0,
            affiliateRewardAmount: 0
        });

        PositionPricingUtils.PositionProFees memory pro = PositionPricingUtils.PositionProFees({
            traderTier: 0,
            traderDiscountFactor: 0,
            traderDiscountAmount: 0
        });

        // allow the accumulated funding fees to still be claimable
        // return the latestFundingFeeAmountPerSize, latestLongTokenClaimableFundingAmountPerSize,
        // latestShortTokenClaimableFundingAmountPerSize values as these may be used to update the
        // position's values if the position will be partially closed
        PositionPricingUtils.PositionFundingFees memory funding = PositionPricingUtils.PositionFundingFees({
            fundingFeeAmount: 0,
            claimableLongTokenAmount: fees.funding.claimableLongTokenAmount,
            claimableShortTokenAmount: fees.funding.claimableShortTokenAmount,
            latestFundingFeeAmountPerSize: fees.funding.latestFundingFeeAmountPerSize,
            latestLongTokenClaimableFundingAmountPerSize: fees.funding.latestLongTokenClaimableFundingAmountPerSize,
            latestShortTokenClaimableFundingAmountPerSize: fees.funding.latestShortTokenClaimableFundingAmountPerSize
        });

        PositionPricingUtils.PositionBorrowingFees memory borrowing = PositionPricingUtils.PositionBorrowingFees({
            borrowingFeeUsd: 0,
            borrowingFeeAmount: 0,
            borrowingFeeReceiverFactor: 0,
            borrowingFeeAmountForFeeReceiver: 0
        });

        PositionPricingUtils.PositionUiFees memory ui = PositionPricingUtils.PositionUiFees({
            uiFeeReceiver: address(0),
            uiFeeReceiverFactor: 0,
            uiFeeAmount: 0
        });

        PositionPricingUtils.PositionLiquidationFees memory liquidation = PositionPricingUtils.PositionLiquidationFees({
            liquidationFeeUsd: 0,
            liquidationFeeAmount: 0,
            liquidationFeeReceiverFactor: 0,
            liquidationFeeAmountForFeeReceiver: 0
        });

        // all fees are zeroed even though funding may have been paid
        // the funding fee amount value may not be accurate in the events due to this
        PositionPricingUtils.PositionFees memory _fees = PositionPricingUtils.PositionFees({
            referral: referral,
            pro: pro,
            funding: funding,
            borrowing: borrowing,
            ui: ui,
            liquidation: liquidation,
            collateralTokenPrice: fees.collateralTokenPrice,
            positionFeeFactor: 0,
            protocolFeeAmount: 0,
            positionFeeReceiverFactor: 0,
            feeReceiverAmount: 0,
            feeAmountForPool: 0,
            positionFeeAmountForPool: 0,
            positionFeeAmount: 0,
            totalCostAmountExcludingFunding: 0,
            totalCostAmount: 0,
            totalDiscountAmount: 0
        });

        return _fees;
    }

    function _getProportionalImpactPendingValues(
        uint256 sizeInUsd,
        int256 positionImpactPendingAmount,
        uint256 sizeDeltaUsd,
        Price.Props memory indexTokenPrice
    ) private pure returns (int256, int256) {
        int256 proportionalPendingImpactAmount = Precision.mulDiv(positionImpactPendingAmount, sizeDeltaUsd, sizeInUsd);

        // minimize the positive impact, maximize the negative impact
        int256 proportionalImpactPendingUsd = proportionalPendingImpactAmount > 0
            ? proportionalPendingImpactAmount * indexTokenPrice.min.toInt256()
            : proportionalPendingImpactAmount * indexTokenPrice.max.toInt256();

        return (proportionalPendingImpactAmount, proportionalImpactPendingUsd);
    }
}
