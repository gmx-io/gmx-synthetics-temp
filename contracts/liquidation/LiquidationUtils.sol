// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../position/PositionStoreUtils.sol";
import "../order/OrderStoreUtils.sol";
import "../order/OrderEventUtils.sol";
import "../nonce/NonceUtils.sol";
import "../callback/CallbackUtils.sol";

// @title LiquidationUtils
// @dev Library to help with liquidations
library LiquidationUtils {
    using Position for Position.Props;
    using Order for Order.Props;

    // @dev creates a liquidation order for a position
    // @param dataStore DataStore
    // @param account the position's account
    // @param market the position's market
    // @param collateralToken the position's collateralToken
    // @param isLong whether the position is long or short
    function createLiquidationOrder(
        DataStore dataStore,
        EventEmitter eventEmitter,
        address account,
        address market,
        address collateralToken,
        bool isLong
    ) external returns (bytes32) {
        bytes32 positionKey = Position.getPositionKey(account, market, collateralToken, isLong);
        Position.Props memory position = PositionStoreUtils.get(dataStore, positionKey);

        Order.Addresses memory addresses = Order.Addresses(
            account, // account
            account, // receiver
            account, // cancellationReceiver
            CallbackUtils.getSavedCallbackContract(dataStore, account, market), // callbackContract
            address(0), // uiFeeReceiver
            market, // market
            position.collateralToken(), // initialCollateralToken
            new address[](0) // swapPath
        );

        // no slippage is set for this order, in case of a liquidation the amount
        // of collateral being swapped should not be too large
        // in case of large price impact, the user could be refunded
        // through a protocol fund if required, this amount could later be claimed
        // from the price impact pool, this claiming process should be added if
        // required
        //
        // setting a maximum price impact that will work for majority of cases
        // may also be challenging since the price impact would vary based on the
        // amount of collateral being swapped
        //
        // note that the decreasePositionSwapType should be SwapPnlTokenToCollateralToken
        // because fees are calculated with reference to the collateral token
        // fees are deducted from the output amount if the output token is the same as the
        // collateral token
        // swapping the pnl token to the collateral token helps to ensure fees can be paid
        // using the realized profit
        Order.Numbers memory numbers = Order.Numbers(
            Order.OrderType.Liquidation, // orderType
            Order.DecreasePositionSwapType.SwapPnlTokenToCollateralToken, // decreasePositionSwapType
            position.sizeInUsd(), // sizeDeltaUsd
            0, // initialCollateralDeltaAmount
            0, // triggerPrice
            position.isLong() ? 0 : type(uint256).max, // acceptablePrice
            0, // executionFee
            dataStore.getUint(Keys.MAX_CALLBACK_GAS_LIMIT), // callbackGasLimit
            0, // minOutputAmount
            Chain.currentTimestamp(), // updatedAtTime
            0 // validFromTime
        );

        Order.Flags memory flags = Order.Flags(
            position.isLong(), // isLong
            true, // shouldUnwrapNativeToken
            false, // isFrozen
            false // autoCancel
        );

        Order.Props memory order = Order.Props(
            addresses,
            numbers,
            flags,
            new bytes32[](0)
        );

        bytes32 key = NonceUtils.getNextKey(dataStore);
        OrderStoreUtils.set(dataStore, key, order);

        OrderEventUtils.emitOrderCreated(eventEmitter, key, order);

        return key;
    }
}
