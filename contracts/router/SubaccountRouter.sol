// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseRouter.sol";
import "../exchange/IOrderHandler.sol";
import "../feature/FeatureUtils.sol";
import "../subaccount/SubaccountUtils.sol";
import "../order/OrderVault.sol";
import "../order/OrderStoreUtils.sol";

contract SubaccountRouter is BaseRouter {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    using Order for Order.Props;

    IOrderHandler public immutable orderHandler;
    OrderVault public immutable orderVault;

    constructor(
        Router _router,
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        IOrderHandler _orderHandler,
        OrderVault _orderVault
    ) BaseRouter(_router, _roleStore, _dataStore, _eventEmitter) {
        orderHandler = _orderHandler;
        orderVault = _orderVault;
    }

    receive() external payable {
        address wnt = TokenUtils.wnt(dataStore);
        if (msg.sender != wnt) {
            revert Errors.InvalidNativeTokenSender(msg.sender);
        }
    }

    function addSubaccount(address subaccount) external payable nonReentrant {
        address account = msg.sender;
        SubaccountUtils.addSubaccount(dataStore, eventEmitter, account, subaccount);
    }

    function removeSubaccount(address subaccount) external payable nonReentrant {
        address account = msg.sender;
        SubaccountUtils.removeSubaccount(dataStore, eventEmitter, account, subaccount);
    }

    function setSubaccountExpiresAt(
        address subaccount,
        bytes32 actionType,
        uint256 expiresAt
    ) external payable nonReentrant {
        address account = msg.sender;
        SubaccountUtils.setSubaccountExpiresAt(dataStore, eventEmitter, account, subaccount, actionType, expiresAt);
    }

    function setMaxAllowedSubaccountActionCount(
        address subaccount,
        bytes32 actionType,
        uint256 maxAllowedCount
    ) external payable nonReentrant {
        address account = msg.sender;

        SubaccountUtils.setMaxAllowedSubaccountActionCount(
            dataStore,
            eventEmitter,
            account,
            subaccount,
            actionType,
            maxAllowedCount
        );
    }

    function setSubaccountAutoTopUpAmount(
        address subaccount,
        uint256 amount
    ) external payable nonReentrant {
        address account = msg.sender;

        SubaccountUtils.setSubaccountAutoTopUpAmount(
            dataStore,
            eventEmitter,
            account,
            subaccount,
            amount
        );
    }

    function createOrder(
        address account,
        IBaseOrderUtils.CreateOrderParams calldata params
    ) external payable nonReentrant returns (bytes32) {
        uint256 startingGas = gasleft();

        _handleSubaccountAction(account, Keys.SUBACCOUNT_ORDER_ACTION);

        if (params.addresses.receiver != account) {
            revert Errors.InvalidReceiverForSubaccountOrder(params.addresses.receiver, account);
        }

        if (
            params.orderType == Order.OrderType.MarketSwap ||
            params.orderType == Order.OrderType.LimitSwap ||
            params.orderType == Order.OrderType.MarketIncrease ||
            params.orderType == Order.OrderType.LimitIncrease ||
            params.orderType == Order.OrderType.StopIncrease
        ) {
            router.pluginTransfer(
                params.addresses.initialCollateralToken, // token
                account, // account
                address(orderVault), // receiver
                params.numbers.initialCollateralDeltaAmount // amount
            );
        }

        bytes32 key = orderHandler.createOrder(
            account,
            params
        );

        _autoTopUpSubaccount(
            account, // account
            msg.sender, // subaccount
            startingGas, // startingGas
            params.numbers.executionFee // executionFee
        );

        return key;
    }

    function updateOrder(
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 acceptablePrice,
        uint256 triggerPrice,
        uint256 minOutputAmount,
        uint256 validFromTime,
        bool autoCancel
    ) external payable nonReentrant {
        uint256 startingGas = gasleft();

        Order.Props memory order = OrderStoreUtils.get(dataStore, key);

        if (order.account() == address(0)) { revert Errors.EmptyOrder(); }

        _handleSubaccountAction(order.account(), Keys.SUBACCOUNT_ORDER_ACTION);

        orderHandler.updateOrder(
            key,
            sizeDeltaUsd,
            acceptablePrice,
            triggerPrice,
            minOutputAmount,
            validFromTime,
            autoCancel,
            order
        );

        _autoTopUpSubaccount(
            order.account(), // account
            msg.sender, // subaccount
            startingGas, // startingGas
            0 // executionFee
        );
    }

    function cancelOrder(
        bytes32 key
    ) external payable nonReentrant {
        uint256 startingGas = gasleft();

        Order.Props memory order = OrderStoreUtils.get(dataStore, key);

        if (order.account() == address(0)) { revert Errors.EmptyOrder(); }

        _handleSubaccountAction(order.account(), Keys.SUBACCOUNT_ORDER_ACTION);

        orderHandler.cancelOrder(key);

        _autoTopUpSubaccount(
            order.account(), // account
            msg.sender, // subaccount
            startingGas, // startingGas
            0 // executionFee
        );
    }

    function _handleSubaccountAction(address account, bytes32 actionType) internal {
        FeatureUtils.validateFeature(dataStore, Keys.subaccountFeatureDisabledKey(address(this)));

        address subaccount = msg.sender;
        SubaccountUtils.handleSubaccountAction(
            dataStore,
            eventEmitter,
            account,
            subaccount,
            actionType
        );
    }

    // the subaccount is topped up with wrapped native tokens
    // the subaccount should separately unwrap the token as needed
    function _autoTopUpSubaccount(address account, address subaccount, uint256 startingGas, uint256 executionFee) internal {
        uint256 amount = SubaccountUtils.getSubaccountAutoTopUpAmount(dataStore, account, subaccount);
        if (amount == 0) {
            return;
        }

        IERC20 wnt = IERC20(dataStore.getAddress(Keys.WNT));

        if (wnt.allowance(account, address(router)) < amount) { return; }
        if (wnt.balanceOf(account) < amount) { return; }

        // cap the top up amount to the amount of native tokens used
        uint256 nativeTokensUsed = (startingGas - gasleft()) * tx.gasprice + executionFee;
        if (nativeTokensUsed < amount) { amount = nativeTokensUsed; }

        router.pluginTransfer(
            address(wnt), // token
            account, // account
            address(this), // receiver
            amount // amount
        );

        TokenUtils.withdrawAndSendNativeToken(
            dataStore,
            address(wnt),
            subaccount,
            amount
        );

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "account", account);
        eventData.addressItems.setItem(1, "subaccount", subaccount);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "amount", amount);

        eventEmitter.emitEventLog2(
            "SubaccountAutoTopUp",
            Cast.toBytes32(account),
            Cast.toBytes32(subaccount),
            eventData
        );
    }
}
