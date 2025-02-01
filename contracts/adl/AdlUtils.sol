// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";

import "../order/OrderStoreUtils.sol";
import "../order/OrderEventUtils.sol";
import "../position/PositionStoreUtils.sol";
import "../nonce/NonceUtils.sol";
import "../callback/CallbackUtils.sol";
import "../market/Market.sol";
import "../market/MarketUtils.sol";
import "../oracle/Oracle.sol";

// @title AdlUtils
// @dev Library to help with auto-deleveraging
// This is particularly for markets with an index token that is different from
// the long token
//
// For example, if there is a DOGE / USD perp market with ETH as the long token
// it would be possible for the price of DOGE to increase faster than the price of
// ETH
//
// In this scenario, profitable positions should be closed through ADL to ensure
// that the system remains fully solvent
library AdlUtils {
    using SafeCast for int256;
    using Market for Market.Props;
    using Position for Position.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    // @dev CreateAdlOrderParams struct used in createAdlOrder to avoid stack
    // too deep errors
    //
    // @param dataStore DataStore
    // @param orderStore OrderStore
    // @param account the account to reduce the position for
    // @param market the position's market
    // @param collateralToken the position's collateralToken
    // @param isLong whether the position is long or short
    // @param sizeDeltaUsd the size to reduce the position by
    struct CreateAdlOrderParams {
        DataStore dataStore;
        EventEmitter eventEmitter;
        address account;
        address market;
        address collateralToken;
        bool isLong;
        uint256 sizeDeltaUsd;
        uint256 updatedAtTime;
    }

    // @dev Multiple positions may need to be reduced to ensure that the pending
    // profits does not exceed the allowed thresholds
    //
    // This automatic reduction of positions can only be done if the pool is in a state
    // where auto-deleveraging is required
    //
    // This function checks the pending profit state and updates an isAdlEnabled
    // flag to avoid having to repeatedly validate whether auto-deleveraging is required
    //
    // Once the pending profit has been reduced below the threshold this function can
    // be called again to clear the flag
    //
    // The ADL check would be possible to do in AdlHandler.executeAdl as well
    // but with that order keepers could use stale oracle prices to prove that
    // an ADL state is possible
    //
    // Having this function allows any order keeper to disable ADL if prices
    // have updated such that ADL is no longer needed
    //
    // @param dataStore DataStore
    // @param eventEmitter EventEmitter
    // @param oracle Oracle
    // @param market address of the market to check
    // @param isLong indicates whether to check the long or short side of the market
    function updateAdlState(
        DataStore dataStore,
        EventEmitter eventEmitter,
        Oracle oracle,
        address market,
        bool isLong
    ) external {
        uint256 latestAdlTime = getLatestAdlTime(dataStore, market, isLong);

        if (oracle.maxTimestamp() < latestAdlTime) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(oracle.maxTimestamp(), latestAdlTime);
        }

        Market.Props memory _market = MarketUtils.getEnabledMarket(dataStore, market);
        MarketUtils.MarketPrices memory prices = MarketUtils.getMarketPrices(oracle, _market);
        // if the MAX_PNL_FACTOR_FOR_ADL is set to be higher than MAX_PNL_FACTOR_FOR_WITHDRAWALS
        // it is possible for a pool to be in a state where withdrawals and ADL is not allowed
        // this is similar to the case where there is a large amount of open positions relative
        // to the amount of tokens in the pool
        (bool shouldEnableAdl, int256 pnlToPoolFactor, uint256 maxPnlFactor) = MarketUtils.isPnlFactorExceeded(
            dataStore,
            _market,
            prices,
            isLong,
            Keys.MAX_PNL_FACTOR_FOR_ADL
        );

        setIsAdlEnabled(dataStore, market, isLong, shouldEnableAdl);
        // since the latest ADL at is always updated, an ADL keeper could
        // continually cause the latest ADL time to be updated and prevent
        // ADL orders from being executed, however, this may be preferrable
        // over a case where stale prices could be used by ADL keepers
        // to execute orders
         // as such updating of the ADL time is allowed and it is expected
        // that ADL keepers will keep this time updated so that latest prices
        // will be used for ADL
        setLatestAdlAt(dataStore, market, isLong, Chain.currentTimestamp());

        emitAdlStateUpdated(eventEmitter, market, isLong, pnlToPoolFactor, maxPnlFactor, shouldEnableAdl);
    }

    // @dev Construct an ADL order
    //
    // A decrease order is used to reduce a profitable position
    //
    // @param params CreateAdlOrderParams
    // @return the key of the created order
    function createAdlOrder(CreateAdlOrderParams memory params) external returns (bytes32) {
        bytes32 positionKey = Position.getPositionKey(params.account, params.market, params.collateralToken, params.isLong);
        Position.Props memory position = PositionStoreUtils.get(params.dataStore, positionKey);

        if (params.sizeDeltaUsd > position.sizeInUsd()) {
            revert Errors.InvalidSizeDeltaForAdl(params.sizeDeltaUsd, position.sizeInUsd());
        }

        Order.Addresses memory addresses = Order.Addresses(
            params.account, // account
            params.account, // receiver
            params.account, // cancellationReceiver
            CallbackUtils.getSavedCallbackContract(params.dataStore, params.account, params.market), // callbackContract
            address(0), // uiFeeReceiver
            params.market, // market
            position.collateralToken(), // initialCollateralToken
            new address[](0) // swapPath
        );

        // no slippage is set for this order, it may be preferrable for ADL orders
        // to be executed, in case of large price impact, the user could be refunded
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
            Order.OrderType.MarketDecrease, // orderType
            Order.DecreasePositionSwapType.SwapPnlTokenToCollateralToken, // decreasePositionSwapType
            params.sizeDeltaUsd, // sizeDeltaUsd
            0, // initialCollateralDeltaAmount
            0, // triggerPrice
            position.isLong() ? 0 : type(uint256).max, // acceptablePrice
            0, // executionFee
            params.dataStore.getUint(Keys.MAX_CALLBACK_GAS_LIMIT), // callbackGasLimit
            0, // minOutputAmount
            params.updatedAtTime, // updatedAtTime
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

        bytes32 key = NonceUtils.getNextKey(params.dataStore);
        OrderStoreUtils.set(params.dataStore, key, order);

        OrderEventUtils.emitOrderCreated(params.eventEmitter, key, order);

        return key;
    }

    // @dev validate if the requested ADL can be executed
    //
    // @param dataStore DataStore
    // @param oracle Oracle
    // @param market address of the market to check
    // @param isLong indicates whether to check the long or short side of the market
    function validateAdl(
        DataStore dataStore,
        Oracle oracle,
        address market,
        bool isLong
    ) external view {
        bool isAdlEnabled = AdlUtils.getIsAdlEnabled(dataStore, market, isLong);
        if (!isAdlEnabled) {
            revert Errors.AdlNotEnabled();
        }

        uint256 latestAdlTime = AdlUtils.getLatestAdlTime(dataStore, market, isLong);
        if (oracle.maxTimestamp() < latestAdlTime) {
            revert Errors.OracleTimestampsAreSmallerThanRequired(oracle.maxTimestamp(), latestAdlTime);
        }
    }

    // @dev get the latest time at which the ADL flag was updated
    //
    // @param dataStore DataStore
    // @param market address of the market to check
    // @param isLong indicates whether to check the long or short side of the market
    //
    // @return the latest time at which the ADL flag was updated
    function getLatestAdlTime(DataStore dataStore, address market, bool isLong) internal view returns (uint256) {
        return dataStore.getUint(Keys.latestAdlAtKey(market, isLong));
    }

    // @dev set the latest time at which the ADL flag was updated
    //
    // @param dataStore DataStore
    // @param market address of the market to check
    // @param isLong indicates whether to check the long or short side of the market
    // @param value the latest time value
    //
    // @return the latest time value
    function setLatestAdlAt(DataStore dataStore, address market, bool isLong, uint256 value) internal returns (uint256) {
        return dataStore.setUint(Keys.latestAdlAtKey(market, isLong), value);
    }

    // @dev get whether ADL is enabled
    //
    // @param dataStore DataStore
    // @param market address of the market to check
    // @param isLong indicates whether to check the long or short side of the market
    //
    // @return whether ADL is enabled
    function getIsAdlEnabled(DataStore dataStore, address market, bool isLong) internal view returns (bool) {
        return dataStore.getBool(Keys.isAdlEnabledKey(market, isLong));
    }

    // @dev set whether ADL is enabled
    //
    // @param dataStore DataStore
    // @param market address of the market to check
    // @param isLong indicates whether to check the long or short side of the market
    // @param value whether ADL is enabled
    //
    // @return whether ADL is enabled
    function setIsAdlEnabled(DataStore dataStore, address market, bool isLong, bool value) internal returns (bool) {
        return dataStore.setBool(Keys.isAdlEnabledKey(market, isLong), value);
    }

    // @dev emit ADL state update events
    //
    // @param eventEmitter EventEmitter
    // @param market address of the market for the ADL state update
    // @param isLong indicates the ADL state update is for the long or short side of the market
    // @param pnlToPoolFactor the ratio of PnL to pool value
    // @param maxPnlFactor the max PnL factor
    // @param shouldEnableAdl whether ADL was enabled or disabled
    function emitAdlStateUpdated(
        EventEmitter eventEmitter,
        address market,
        bool isLong,
        int256 pnlToPoolFactor,
        uint256 maxPnlFactor,
        bool shouldEnableAdl
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.intItems.initItems(1);
        eventData.intItems.setItem(0, "pnlToPoolFactor", pnlToPoolFactor);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "maxPnlFactor", maxPnlFactor);

        eventData.boolItems.initItems(2);
        eventData.boolItems.setItem(0, "isLong", isLong);
        eventData.boolItems.setItem(1, "shouldEnableAdl", shouldEnableAdl);

        eventEmitter.emitEventLog1(
            "AdlStateUpdated",
            Cast.toBytes32(market),
            eventData
        );
    }
}
