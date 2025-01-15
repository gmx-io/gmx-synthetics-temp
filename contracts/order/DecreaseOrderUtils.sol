// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseOrderUtils.sol";
import "../swap/SwapUtils.sol";
import "../position/DecreasePositionUtils.sol";
import "../error/ErrorUtils.sol";

// @title DecreaseOrderUtils
// @dev Library for functions to help with processing a decrease order
// note that any updates to the eventData
library DecreaseOrderUtils {
    using Position for Position.Props;
    using Order for Order.Props;
    using Array for uint256[];

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    // @dev process a decrease order
    // @param params BaseOrderUtils.ExecuteOrderParams
    function processOrder(BaseOrderUtils.ExecuteOrderParams memory params) external returns (EventUtils.EventLogData memory) {
        Order.Props memory order = params.order;
        MarketUtils.validatePositionMarket(params.contracts.dataStore, params.market);

        bytes32 positionKey = Position.getPositionKey(order.account(), order.market(), order.initialCollateralToken(), order.isLong());
        Position.Props memory position = PositionStoreUtils.get(params.contracts.dataStore, positionKey);
        PositionUtils.validateNonEmptyPosition(position);

        validateOracleTimestamp(
            params.contracts.dataStore,
            order.orderType(),
            order.market(),
            order.updatedAtTime(),
            order.validFromTime(),
            position.increasedAtTime(),
            position.decreasedAtTime(),
            params.minOracleTimestamp,
            params.maxOracleTimestamp
        );

        DecreasePositionUtils.DecreasePositionResult memory result = DecreasePositionUtils.decreasePosition(
            PositionUtils.UpdatePositionParams(
                params.contracts,
                params.market,
                order,
                params.key,
                position,
                positionKey,
                params.secondaryOrderType
            )
        );

        // if the pnlToken and the collateralToken are different
        // and if a swap fails or no swap was requested
        // then it is possible to receive two separate tokens from decreasing
        // the position
        // transfer the two tokens to the user in this case and skip processing
        // the swapPath
        if (result.secondaryOutputAmount > 0) {
            _validateOutputAmount(
                params.contracts.oracle,
                result.outputToken,
                result.outputAmount,
                result.secondaryOutputToken,
                result.secondaryOutputAmount,
                order.minOutputAmount()
            );

            MarketToken(payable(order.market())).transferOut(
                result.outputToken,
                order.receiver(),
                result.outputAmount,
                order.shouldUnwrapNativeToken()
            );

            MarketToken(payable(order.market())).transferOut(
                result.secondaryOutputToken,
                order.receiver(),
                result.secondaryOutputAmount,
                order.shouldUnwrapNativeToken()
            );

            return getOutputEventData(
                result.outputToken,
                result.outputAmount,
                result.secondaryOutputToken,
                result.secondaryOutputAmount,
                result.orderSizeDeltaUsd,
                result.orderInitialCollateralDeltaAmount
            );
        }

        try params.contracts.swapHandler.swap(
            SwapUtils.SwapParams(
                params.contracts.dataStore,
                params.contracts.eventEmitter,
                params.contracts.oracle,
                Bank(payable(order.market())),
                params.key,
                result.outputToken,
                result.outputAmount,
                params.swapPathMarkets,
                0,
                order.receiver(),
                order.uiFeeReceiver(),
                order.shouldUnwrapNativeToken()
            )
        ) returns (address tokenOut, uint256 swapOutputAmount) {
            _validateOutputAmount(
                params.contracts.oracle,
                tokenOut,
                swapOutputAmount,
                order.minOutputAmount()
            );

            return getOutputEventData(
                tokenOut,
                swapOutputAmount,
                address(0),
                0,
                result.orderSizeDeltaUsd,
                result.orderInitialCollateralDeltaAmount
            );
        } catch (bytes memory reasonBytes) {
            (string memory reason, /* bool hasRevertMessage */) = ErrorUtils.getRevertMessage(reasonBytes);

            _handleSwapError(
                params.contracts.oracle,
                order,
                result,
                reason,
                reasonBytes
            );

            return getOutputEventData(
                result.outputToken,
                result.outputAmount,
                address(0),
                0,
                result.orderSizeDeltaUsd,
                result.orderInitialCollateralDeltaAmount
            );
        }
    }

    function validateOracleTimestamp(
        DataStore dataStore,
        Order.OrderType orderType,
        address market,
        uint256 orderUpdatedAtTime,
        uint256 orderValidFromTime,
        uint256 positionIncreasedAtTime,
        uint256 positionDecreasedAtTime,
        uint256 minOracleTimestamp,
        uint256 maxOracleTimestamp
    ) internal view {
        if (orderType == Order.OrderType.MarketDecrease) {
            if (minOracleTimestamp < orderUpdatedAtTime) {
                revert Errors.OracleTimestampsAreSmallerThanRequired(market, minOracleTimestamp, orderUpdatedAtTime);
            }

            uint256 requestExpirationTime = dataStore.getUint(Keys.REQUEST_EXPIRATION_TIME);

            if (maxOracleTimestamp > orderUpdatedAtTime + requestExpirationTime) {
                revert Errors.OracleTimestampsAreLargerThanRequestExpirationTime(
                    maxOracleTimestamp,
                    orderUpdatedAtTime,
                    requestExpirationTime
                );
            }
            return;
        }

        if (
            !BaseOrderUtils.isMarketOrder(orderType) &&
            minOracleTimestamp < orderValidFromTime
        ) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(market, minOracleTimestamp, orderValidFromTime);
        }

        // a user could attempt to frontrun prices by creating a limit decrease
        // order without a position
        // when price moves in the user's favour, the user would create a
        // position then
        // e.g. price is $5000, a user creates a stop-loss order to
        // close a long position when price is below $5000
        // if price decreases to $4995, the user opens a long position at
        // price $4995
        // since slightly older prices may be used to execute a position
        // the user's stop-loss order could be executed at price $5000
        // for this reason, both the orderUpdatedAtTime and the
        // positionIncreasedAtTime need to be used as a reference
        //
        // if there are multiple decrease orders, an execution of one decrease
        // order would update the position, so the reference check here is only
        // with positionIncreasedAtTime instead of a positionUpdatedAtTime value
        if (
            orderType == Order.OrderType.LimitDecrease ||
            orderType == Order.OrderType.StopLossDecrease
        ) {
            uint256 latestUpdatedAtTime = orderUpdatedAtTime > positionIncreasedAtTime ? orderUpdatedAtTime : positionIncreasedAtTime;
            if (minOracleTimestamp < latestUpdatedAtTime) {
                revert Errors.OracleTimestampsAreSmallerThanRequired(market, minOracleTimestamp, latestUpdatedAtTime);
            }
            return;
        }

        if (orderType == Order.OrderType.Liquidation) {
            uint256 latestUpdatedAtTime = positionIncreasedAtTime > positionDecreasedAtTime ? positionIncreasedAtTime : positionDecreasedAtTime;
            if (minOracleTimestamp < latestUpdatedAtTime) {
                revert Errors.OracleTimestampsAreSmallerThanRequired(market, minOracleTimestamp, latestUpdatedAtTime);
            }
            return;
        }

        revert Errors.UnsupportedOrderType(uint256(orderType));
    }

    // note that minOutputAmount is treated as a USD value for this validation
    function _validateOutputAmount(
        Oracle oracle,
        address outputToken,
        uint256 outputAmount,
        uint256 minOutputAmount
    ) internal view {
        uint256 outputTokenPrice = oracle.getPrimaryPrice(outputToken).min;
        uint256 outputUsd = outputAmount * outputTokenPrice;

        if (outputUsd < minOutputAmount) {
            revert Errors.InsufficientOutputAmount(outputUsd, minOutputAmount);
        }
    }

    // note that minOutputAmount is treated as a USD value for this validation
    function _validateOutputAmount(
        Oracle oracle,
        address outputToken,
        uint256 outputAmount,
        address secondaryOutputToken,
        uint256 secondaryOutputAmount,
        uint256 minOutputAmount
    ) internal view {
        uint256 outputTokenPrice = oracle.getPrimaryPrice(outputToken).min;
        uint256 outputUsd = outputAmount * outputTokenPrice;

        uint256 secondaryOutputTokenPrice = oracle.getPrimaryPrice(secondaryOutputToken).min;
        uint256 secondaryOutputUsd = secondaryOutputAmount * secondaryOutputTokenPrice;

        uint256 totalOutputUsd = outputUsd + secondaryOutputUsd;

        if (totalOutputUsd < minOutputAmount) {
            revert Errors.InsufficientOutputAmount(totalOutputUsd, minOutputAmount);
        }
    }

    function _handleSwapError(
        Oracle oracle,
        Order.Props memory order,
        DecreasePositionUtils.DecreasePositionResult memory result,
        string memory reason,
        bytes memory reasonBytes
    ) internal {
        emit SwapUtils.SwapReverted(reason, reasonBytes);

        _validateOutputAmount(
            oracle,
            result.outputToken,
            result.outputAmount,
            order.minOutputAmount()
        );

        MarketToken(payable(order.market())).transferOut(
            result.outputToken,
            order.receiver(),
            result.outputAmount,
            order.shouldUnwrapNativeToken()
        );
    }

    function getOutputEventData(
        address outputToken,
        uint256 outputAmount,
        address secondaryOutputToken,
        uint256 secondaryOutputAmount,
        uint256 orderSizeDeltaUsd,
        uint256 orderInitialCollateralDeltaAmount
    ) internal pure returns (EventUtils.EventLogData memory) {
        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "outputToken", outputToken);
        eventData.addressItems.setItem(1, "secondaryOutputToken", secondaryOutputToken);

        eventData.uintItems.initItems(4);
        eventData.uintItems.setItem(0, "outputAmount", outputAmount);
        eventData.uintItems.setItem(1, "secondaryOutputAmount", secondaryOutputAmount);
        eventData.uintItems.setItem(2, "orderSizeDeltaUsd", orderSizeDeltaUsd);
        eventData.uintItems.setItem(3, "orderInitialCollateralDeltaAmount", orderInitialCollateralDeltaAmount);

        return eventData;
    }
}
