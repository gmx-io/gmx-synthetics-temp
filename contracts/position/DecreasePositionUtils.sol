// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../utils/Precision.sol";

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "../oracle/Oracle.sol";
import "../pricing/PositionPricingUtils.sol";

import "./Position.sol";
import "./PositionStoreUtils.sol";
import "./PositionUtils.sol";
import "./PositionEventUtils.sol";
import "../order/BaseOrderUtils.sol";
import "../order/OrderEventUtils.sol";

import "./DecreasePositionCollateralUtils.sol";

// @title DecreasePositionUtils
// @dev Library for functions to help with decreasing a position
library DecreasePositionUtils {
    using SafeCast for uint256;
    using SafeCast for int256;

    using Position for Position.Props;
    using Order for Order.Props;
    using Price for Price.Props;

    // @dev DecreasePositionResult struct for the results of decreasePosition
    // @param outputToken the output token
    // @param outputAmount the output amount
    // @param secondaryOutputToken the secondary output token
    // @param secondaryOutputAmount the secondary output amount
    struct DecreasePositionResult {
        address outputToken;
        uint256 outputAmount;
        address secondaryOutputToken;
        uint256 secondaryOutputAmount;
        uint256 orderSizeDeltaUsd;
        uint256 orderInitialCollateralDeltaAmount;
    }

    // @dev decreases a position
    // The decreasePosition function decreases the size of an existing position
    // in a market. It takes a PositionUtils.UpdatePositionParams object as an input, which
    // includes information about the position to be decreased, the market in
    // which the position exists, and the order that is being used to decrease the position.
    //
    // The function first calculates the prices of the tokens in the market, and then
    // checks whether the position is liquidatable based on the current market prices.
    // If the order is a liquidation order and the position is not liquidatable, the function reverts.
    //
    // If there is not enough collateral in the position to complete the decrease,
    // the function reverts. Otherwise, the function updates the position's size and
    // collateral amount, and increments the claimable funding amount for
    // the market if necessary.
    //
    // Finally, the function returns a DecreasePositionResult object containing
    // information about the outcome of the decrease operation, including the amount
    // of collateral removed from the position and any fees that were paid.
    // @param params PositionUtils.UpdatePositionParams
    function decreasePosition(
        PositionUtils.UpdatePositionParams memory params
    ) external returns (DecreasePositionResult memory) {
        PositionUtils.DecreasePositionCache memory cache;

        cache.prices = MarketUtils.getMarketPrices(
            params.contracts.oracle,
            params.market
        );

        cache.collateralTokenPrice = MarketUtils.getCachedTokenPrice(
            params.order.initialCollateralToken(),
            params.market,
            cache.prices
        );

        // cap the order size to the position size
        if (params.order.sizeDeltaUsd() > params.position.sizeInUsd()) {
            if (params.order.orderType() == Order.OrderType.LimitDecrease ||
                params.order.orderType() == Order.OrderType.StopLossDecrease) {

                OrderEventUtils.emitOrderSizeDeltaAutoUpdated(
                    params.contracts.eventEmitter,
                    params.orderKey,
                    params.order.sizeDeltaUsd(),
                    params.position.sizeInUsd()
                );

                params.order.setSizeDeltaUsd(params.position.sizeInUsd());
            } else {
                revert Errors.InvalidDecreaseOrderSize(params.order.sizeDeltaUsd(), params.position.sizeInUsd());
            }
        }

        // cap the initialCollateralDeltaAmount to the position collateralAmount
        if (params.order.initialCollateralDeltaAmount() > params.position.collateralAmount()) {
            OrderEventUtils.emitOrderCollateralDeltaAmountAutoUpdated(
                params.contracts.eventEmitter,
                params.orderKey,
                params.order.initialCollateralDeltaAmount(),
                params.position.collateralAmount()
            );

            params.order.setInitialCollateralDeltaAmount(params.position.collateralAmount());
        }

        // if the position will be partially decreased then do a check on the
        // remaining collateral amount and update the order attributes if needed
        if (params.order.sizeDeltaUsd() < params.position.sizeInUsd()) {
            // estimate pnl based on indexTokenPrice
            (cache.estimatedPositionPnlUsd, /* int256 uncappedBasePnlUsd */,  /* uint256 sizeDeltaInTokens */) = PositionUtils.getPositionPnlUsd(
                params.contracts.dataStore,
                params.market,
                cache.prices,
                params.position,
                params.position.sizeInUsd()
            );

            cache.estimatedRealizedPnlUsd = Precision.mulDiv(cache.estimatedPositionPnlUsd, params.order.sizeDeltaUsd(), params.position.sizeInUsd());
            cache.estimatedRemainingPnlUsd = cache.estimatedPositionPnlUsd - cache.estimatedRealizedPnlUsd;

            PositionUtils.WillPositionCollateralBeSufficientValues memory positionValues = PositionUtils.WillPositionCollateralBeSufficientValues(
                params.position.sizeInUsd() - params.order.sizeDeltaUsd(), // positionSizeInUsd
                params.position.collateralAmount() - params.order.initialCollateralDeltaAmount(), // positionCollateralAmount
                cache.estimatedRealizedPnlUsd,  // realizedPnlUsd
                -params.order.sizeDeltaUsd().toInt256() // openInterestDelta
            );

            (bool willBeSufficient, int256 estimatedRemainingCollateralUsd) = PositionUtils.willPositionCollateralBeSufficient(
                params.contracts.dataStore,
                params.market,
                cache.prices,
                params.position.collateralToken(),
                params.position.isLong(),
                positionValues
            );

            // do not allow withdrawal of collateral if it would lead to the position
            // having an insufficient amount of collateral
            // this helps to prevent gaming by opening a position then reducing collateral
            // to increase the leverage of the position
            if (!willBeSufficient) {
                if (params.order.sizeDeltaUsd() == 0) {
                    revert Errors.UnableToWithdrawCollateral(estimatedRemainingCollateralUsd);
                }

                OrderEventUtils.emitOrderCollateralDeltaAmountAutoUpdated(
                    params.contracts.eventEmitter,
                    params.orderKey,
                    params.order.initialCollateralDeltaAmount(),
                    0
                );

                // the estimatedRemainingCollateralUsd subtracts the initialCollateralDeltaAmount
                // since the initialCollateralDeltaAmount will be set to zero, the initialCollateralDeltaAmount
                // should be added back to the estimatedRemainingCollateralUsd
                estimatedRemainingCollateralUsd += (params.order.initialCollateralDeltaAmount() * cache.collateralTokenPrice.min).toInt256();
                params.order.setInitialCollateralDeltaAmount(0);
            }

            // if the remaining collateral including position pnl will be below
            // the min collateral usd value, then close the position
            //
            // if the position has sufficient remaining collateral including pnl
            // then allow the position to be partially closed and the updated
            // position to remain open
            if ((estimatedRemainingCollateralUsd + cache.estimatedRemainingPnlUsd) < params.contracts.dataStore.getUint(Keys.MIN_COLLATERAL_USD).toInt256()) {
                OrderEventUtils.emitOrderSizeDeltaAutoUpdated(
                    params.contracts.eventEmitter,
                    params.orderKey,
                    params.order.sizeDeltaUsd(),
                    params.position.sizeInUsd()
                );

                params.order.setSizeDeltaUsd(params.position.sizeInUsd());
            }

            if (
                params.position.sizeInUsd() > params.order.sizeDeltaUsd()  &&
                params.position.sizeInUsd() - params.order.sizeDeltaUsd() < params.contracts.dataStore.getUint(Keys.MIN_POSITION_SIZE_USD)
            ) {
                OrderEventUtils.emitOrderSizeDeltaAutoUpdated(
                    params.contracts.eventEmitter,
                    params.orderKey,
                    params.order.sizeDeltaUsd(),
                    params.position.sizeInUsd()
                );

                params.order.setSizeDeltaUsd(params.position.sizeInUsd());
            }
        }

        // if the position will be closed, set the initial collateral delta amount
        // to zero to help ensure that the order can be executed
        if (params.order.sizeDeltaUsd() == params.position.sizeInUsd() && params.order.initialCollateralDeltaAmount() > 0) {
            params.order.setInitialCollateralDeltaAmount(0);
        }

        cache.pnlToken = params.position.isLong() ? params.market.longToken : params.market.shortToken;
        cache.pnlTokenPrice = params.position.isLong() ? cache.prices.longTokenPrice : cache.prices.shortTokenPrice;

        if (params.order.decreasePositionSwapType() != Order.DecreasePositionSwapType.NoSwap &&
            cache.pnlToken == params.position.collateralToken()) {
            params.order.setDecreasePositionSwapType(Order.DecreasePositionSwapType.NoSwap);
        }

        if (BaseOrderUtils.isLiquidationOrder(params.order.orderType())) {
            (bool isLiquidatable, string memory reason, PositionUtils.IsPositionLiquidatableInfo memory info) = PositionUtils.isPositionLiquidatable(
                params.contracts.dataStore,
                params.contracts.referralStorage,
                params.position,
                params.market,
                cache.prices,
                true // shouldValidateMinCollateralUsd
            );

            if (!isLiquidatable) {
                revert Errors.PositionShouldNotBeLiquidated(
                    reason,
                    info.remainingCollateralUsd,
                    info.minCollateralUsd,
                    info.minCollateralUsdForLeverage
                );
            }
        }

        cache.initialCollateralAmount = params.position.collateralAmount();
        (
            PositionUtils.DecreasePositionCollateralValues memory values,
            PositionPricingUtils.PositionFees memory fees
        ) = DecreasePositionCollateralUtils.processCollateral(
            params,
            cache
        );

        cache.nextPositionSizeInUsd = params.position.sizeInUsd() - params.order.sizeDeltaUsd();
        cache.nextPositionBorrowingFactor = MarketUtils.getCumulativeBorrowingFactor(params.contracts.dataStore, params.market.marketToken, params.position.isLong());

        PositionUtils.updateTotalBorrowing(
            params,
            cache.nextPositionSizeInUsd,
            cache.nextPositionBorrowingFactor
        );

        params.position.setSizeInUsd(cache.nextPositionSizeInUsd);
        params.position.setSizeInTokens(params.position.sizeInTokens() - values.sizeDeltaInTokens);
        params.position.setCollateralAmount(values.remainingCollateralAmount);
        params.position.setPendingImpactAmount(params.position.pendingImpactAmount() - values.proportionalPendingImpactAmount);
        params.position.setDecreasedAtTime(Chain.currentTimestamp());

        PositionUtils.incrementClaimableFundingAmount(params, fees);

        if (params.position.sizeInUsd() == 0 || params.position.sizeInTokens() == 0) {
            // withdraw all collateral if the position will be closed
            values.output.outputAmount += params.position.collateralAmount();

            params.position.setSizeInUsd(0);
            params.position.setSizeInTokens(0);
            params.position.setCollateralAmount(0);

            PositionStoreUtils.remove(params.contracts.dataStore, params.positionKey, params.order.account());
        } else {
            params.position.setBorrowingFactor(cache.nextPositionBorrowingFactor);

            params.position.setFundingFeeAmountPerSize(fees.funding.latestFundingFeeAmountPerSize);
            params.position.setLongTokenClaimableFundingAmountPerSize(fees.funding.latestLongTokenClaimableFundingAmountPerSize);
            params.position.setShortTokenClaimableFundingAmountPerSize(fees.funding.latestShortTokenClaimableFundingAmountPerSize);

            PositionStoreUtils.set(params.contracts.dataStore, params.positionKey, params.position);
        }

        MarketUtils.applyDeltaToCollateralSum(
            params.contracts.dataStore,
            params.contracts.eventEmitter,
            params.position.market(),
            params.position.collateralToken(),
            params.position.isLong(),
            -(cache.initialCollateralAmount - params.position.collateralAmount()).toInt256()
        );

        PositionUtils.updateOpenInterest(
            params,
            -params.order.sizeDeltaUsd().toInt256(),
            -values.sizeDeltaInTokens.toInt256()
        );

        // affiliate rewards are still distributed even if the order is a liquidation order
        // this is expected as a partial liquidation is considered the same as an automatic
        // closing of a position
        PositionUtils.handleReferral(params, fees);

        // validatePosition should be called after open interest and all other market variables
        // have been updated
        if (params.position.sizeInUsd() != 0 || params.position.sizeInTokens() != 0) {
            // validate position which validates liquidation state is only called
            // if the remaining position size is not zero
            // due to this, a user can still manually close their position if
            // it is in a partially liquidatable state
            // this should not cause any issues as a liquidation is the same
            // as automatically closing a position
            // the only difference is that if the position has insufficient / negative
            // collateral a liquidation transaction should still complete
            // while a manual close transaction should revert
            PositionUtils.validatePosition(
                params.contracts.dataStore,
                params.contracts.referralStorage,
                params.position,
                params.market,
                cache.prices,
                false, // shouldValidateMinPositionSize
                false // shouldValidateMinCollateralUsd
            );
        }

        PositionEventUtils.emitPositionFeesCollected(
            params.contracts.eventEmitter,
            params.orderKey,
            params.positionKey,
            params.market.marketToken,
            params.position.collateralToken(),
            params.order.sizeDeltaUsd(),
            false,
            fees
        );

        PositionEventUtils.emitPositionDecrease(
            params.contracts.eventEmitter,
            params.orderKey,
            params.positionKey,
            params.position,
            params.order.sizeDeltaUsd(),
            cache.initialCollateralAmount - params.position.collateralAmount(),
            params.order.orderType(),
            values,
            cache.prices.indexTokenPrice,
            cache.collateralTokenPrice
        );

        values = DecreasePositionSwapUtils.swapWithdrawnCollateralToPnlToken(params, values);

        return DecreasePositionResult(
            values.output.outputToken,
            values.output.outputAmount,
            values.output.secondaryOutputToken,
            values.output.secondaryOutputAmount,
            params.order.sizeDeltaUsd(),
            params.order.initialCollateralDeltaAmount()
        );
    }
}
