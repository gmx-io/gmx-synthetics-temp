// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";

import "./Shift.sol";

library ShiftEventUtils {
    using Shift for Shift.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    function emitShiftCreated(
        EventEmitter eventEmitter,
        bytes32 key,
        Shift.Props memory shift
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(6);
        eventData.addressItems.setItem(0, "account", shift.account());
        eventData.addressItems.setItem(1, "receiver", shift.receiver());
        eventData.addressItems.setItem(2, "callbackContract", shift.callbackContract());
        eventData.addressItems.setItem(3, "fromMarket", shift.fromMarket());
        eventData.addressItems.setItem(4, "toMarket", shift.toMarket());
        eventData.addressItems.setItem(5, "uiFeeReceiver", shift.uiFeeReceiver());

        eventData.uintItems.initItems(5);
        eventData.uintItems.setItem(0, "marketTokenAmount", shift.marketTokenAmount());
        eventData.uintItems.setItem(1, "minMarketTokens", shift.minMarketTokens());
        eventData.uintItems.setItem(2, "updatedAtTime", shift.updatedAtTime());
        eventData.uintItems.setItem(3, "executionFee", shift.executionFee());
        eventData.uintItems.setItem(4, "callbackGasLimit", shift.callbackGasLimit());

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventEmitter.emitEventLog2(
            "ShiftCreated",
            key,
            Cast.toBytes32(shift.account()),
            eventData
        );
    }

    function emitShiftExecuted(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        uint256 receivedMarketTokens
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "receivedMarketTokens", receivedMarketTokens);

        eventEmitter.emitEventLog2(
            "ShiftExecuted",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitShiftCancelled(
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
            "ShiftCancelled",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }
}
