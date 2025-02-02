// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../utils/Cast.sol";

import "./Order.sol";

library OrderEventUtils {
    using Order for Order.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    function emitOrderCreated(
        EventEmitter eventEmitter,
        bytes32 key,
        Order.Props memory order
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(7);
        eventData.addressItems.setItem(0, "account", order.account());
        eventData.addressItems.setItem(1, "receiver", order.receiver());
        eventData.addressItems.setItem(2, "callbackContract", order.callbackContract());
        eventData.addressItems.setItem(3, "uiFeeReceiver", order.uiFeeReceiver());
        eventData.addressItems.setItem(4, "market", order.market());
        eventData.addressItems.setItem(5, "initialCollateralToken", order.initialCollateralToken());
        eventData.addressItems.setItem(6, "cancellationReceiver", order.cancellationReceiver());

        eventData.addressItems.initArrayItems(1);
        eventData.addressItems.setItem(0, "swapPath", order.swapPath());

        eventData.uintItems.initItems(11);
        eventData.uintItems.setItem(0, "orderType", uint256(order.orderType()));
        eventData.uintItems.setItem(1, "decreasePositionSwapType", uint256(order.decreasePositionSwapType()));
        eventData.uintItems.setItem(2, "sizeDeltaUsd", order.sizeDeltaUsd());
        eventData.uintItems.setItem(3, "initialCollateralDeltaAmount", order.initialCollateralDeltaAmount());
        eventData.uintItems.setItem(4, "triggerPrice", order.triggerPrice());
        eventData.uintItems.setItem(5, "acceptablePrice", order.acceptablePrice());
        eventData.uintItems.setItem(6, "executionFee", order.executionFee());
        eventData.uintItems.setItem(7, "callbackGasLimit", order.callbackGasLimit());
        eventData.uintItems.setItem(8, "minOutputAmount", order.minOutputAmount());
        eventData.uintItems.setItem(9, "updatedAtTime", order.updatedAtTime());
        eventData.uintItems.setItem(10, "validFromTime", order.validFromTime());

        eventData.boolItems.initItems(3);
        eventData.boolItems.setItem(0, "isLong", order.isLong());
        eventData.boolItems.setItem(1, "shouldUnwrapNativeToken", order.shouldUnwrapNativeToken());
        eventData.boolItems.setItem(2, "autoCancel", order.autoCancel());

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.bytes32Items.initArrayItems(1);
        eventData.bytes32Items.setItem(0, "dataList", order.dataList());

        eventEmitter.emitEventLog2(
            "OrderCreated",
            key,
            Cast.toBytes32(order.account()),
            eventData
        );
    }

    function emitOrderExecuted(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        Order.SecondaryOrderType secondaryOrderType
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "secondaryOrderType", uint256(secondaryOrderType));

        eventEmitter.emitEventLog2(
            "OrderExecuted",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitOrderUpdated(
        EventEmitter eventEmitter,
        bytes32 key,
        Order.Props memory order
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", order.account());

        eventData.uintItems.initItems(6);
        eventData.uintItems.setItem(0, "sizeDeltaUsd", order.sizeDeltaUsd());
        eventData.uintItems.setItem(1, "acceptablePrice", order.acceptablePrice());
        eventData.uintItems.setItem(2, "triggerPrice", order.triggerPrice());
        eventData.uintItems.setItem(3, "minOutputAmount", order.minOutputAmount());
        eventData.uintItems.setItem(4, "updatedAtTime", order.updatedAtTime());
        eventData.uintItems.setItem(5, "validFromTime", order.validFromTime());

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "autoCancel", order.autoCancel());

        eventData.bytes32Items.initArrayItems(1);
        eventData.bytes32Items.setItem(0, "dataList", order.dataList());

        eventEmitter.emitEventLog2(
            "OrderUpdated",
            key,
            Cast.toBytes32(order.account()),
            eventData
        );
    }

    function emitOrderSizeDeltaAutoUpdated(
        EventEmitter eventEmitter,
        bytes32 key,
        uint256 sizeDeltaUsd,
        uint256 nextSizeDeltaUsd
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "sizeDeltaUsd", sizeDeltaUsd);
        eventData.uintItems.setItem(1, "nextSizeDeltaUsd", nextSizeDeltaUsd);

        eventEmitter.emitEventLog1(
            "OrderSizeDeltaAutoUpdated",
            key,
            eventData
        );
    }

    function emitOrderCollateralDeltaAmountAutoUpdated(
        EventEmitter eventEmitter,
        bytes32 key,
        uint256 collateralDeltaAmount,
        uint256 nextCollateralDeltaAmount
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "collateralDeltaAmount", collateralDeltaAmount);
        eventData.uintItems.setItem(1, "nextCollateralDeltaAmount", nextCollateralDeltaAmount);

        eventEmitter.emitEventLog1(
            "OrderCollateralDeltaAmountAutoUpdated",
            key,
            eventData
        );
    }

    function emitOrderCancelled(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        string memory reason,
        bytes memory reasonBytes
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.stringItems.initItems(1);
        eventData.stringItems.setItem(0, "reason", reason);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "reasonBytes", reasonBytes);

        eventEmitter.emitEventLog2(
            "OrderCancelled",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitOrderFrozen(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        string memory reason,
        bytes memory reasonBytes
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.stringItems.initItems(1);
        eventData.stringItems.setItem(0, "reason", reason);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "reasonBytes", reasonBytes);

        eventEmitter.emitEventLog2(
            "OrderFrozen",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }
}
