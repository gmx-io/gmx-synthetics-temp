// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseOrderUtils.sol";
import "../swap/SwapUtils.sol";
import "../position/IncreasePositionUtils.sol";

// @title IncreaseOrderUtils
// @dev Library for functions to help with processing an increase order
library IncreaseOrderUtils {
    using Position for Position.Props;
    using Order for Order.Props;
    using Array for uint256[];

    // @dev process an increase order
    // @param params BaseOrderUtils.ExecuteOrderParams
    function processOrder(BaseOrderUtils.ExecuteOrderParams memory params) external returns (EventUtils.EventLogData memory) {
        MarketUtils.validatePositionMarket(params.contracts.dataStore, params.market);

        (address collateralToken, uint256 collateralIncrementAmount) = SwapUtils.swap(SwapUtils.SwapParams(
            params.contracts.dataStore,
            params.contracts.eventEmitter,
            params.contracts.oracle,
            params.contracts.orderVault,
            params.key,
            params.order.initialCollateralToken(),
            params.order.initialCollateralDeltaAmount(),
            params.swapPathMarkets,
            params.order.minOutputAmount(),
            params.order.market(),
            params.order.uiFeeReceiver(),
            false
        ));

        MarketUtils.validateMarketCollateralToken(params.market, collateralToken);

        bytes32 positionKey = Position.getPositionKey(params.order.account(), params.order.market(), collateralToken, params.order.isLong());
        Position.Props memory position = PositionStoreUtils.get(params.contracts.dataStore, positionKey);

        // initialize position
        if (position.account() == address(0)) {
            position.setAccount(params.order.account());
            if (position.market() != address(0) || position.collateralToken() != address(0)) {
                revert Errors.UnexpectedPositionState();
            }

            position.setMarket(params.order.market());
            position.setCollateralToken(collateralToken);
            position.setIsLong(params.order.isLong());
        }

        if (params.minOracleTimestamp < params.order.updatedAtTime()) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(
                params.order.market(),
                params.minOracleTimestamp,
                params.order.updatedAtTime()
            );
        }

        if (
            !BaseOrderUtils.isMarketOrder(params.order.orderType()) &&
            params.minOracleTimestamp < params.order.validFromTime()
        ) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(
                params.order.market(),
                params.minOracleTimestamp,
                params.order.validFromTime()
            );
        }

        uint256 requestExpirationTime = params.contracts.dataStore.getUint(Keys.REQUEST_EXPIRATION_TIME);

        if (
            params.order.orderType() == Order.OrderType.MarketIncrease &&
            params.maxOracleTimestamp > params.order.updatedAtTime() + requestExpirationTime
        ) {
            revert Errors.OracleTimestampsAreLargerThanRequestExpirationTime(
                params.maxOracleTimestamp,
                params.order.updatedAtTime(),
                requestExpirationTime
            );
        }

        IncreasePositionUtils.increasePosition(
            PositionUtils.UpdatePositionParams(
                params.contracts,
                params.market,
                params.order,
                params.key,
                position,
                positionKey,
                params.secondaryOrderType
            ),
            collateralIncrementAmount
        );

        EventUtils.EventLogData memory eventData;
        return eventData;
    }
}
