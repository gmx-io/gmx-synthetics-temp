// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../event/EventEmitter.sol";
import "../../event/EventUtils.sol";
import "../../utils/Cast.sol";

import "./GlvWithdrawal.sol";

library GlvWithdrawalEventUtils {
    using GlvWithdrawal for GlvWithdrawal.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    function emitGlvWithdrawalCreated(
        EventEmitter eventEmitter,
        bytes32 key,
        GlvWithdrawal.Props memory glvWithdrawal
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(6);
        eventData.addressItems.setItem(0, "account", glvWithdrawal.account());
        eventData.addressItems.setItem(1, "receiver", glvWithdrawal.receiver());
        eventData.addressItems.setItem(2, "callbackContract", glvWithdrawal.callbackContract());
        eventData.addressItems.setItem(3, "market", glvWithdrawal.market());
        eventData.addressItems.setItem(4, "glv", glvWithdrawal.glv());
        eventData.addressItems.setItem(5, "uiFeeReceiver", glvWithdrawal.uiFeeReceiver());

        eventData.addressItems.initArrayItems(2);
        eventData.addressItems.setItem(0, "longTokenSwapPath", glvWithdrawal.longTokenSwapPath());
        eventData.addressItems.setItem(1, "shortTokenSwapPath", glvWithdrawal.shortTokenSwapPath());

        eventData.uintItems.initItems(6);
        eventData.uintItems.setItem(0, "glvTokenAmount", glvWithdrawal.glvTokenAmount());
        eventData.uintItems.setItem(1, "minLongTokenAmount", glvWithdrawal.minLongTokenAmount());
        eventData.uintItems.setItem(2, "minShortTokenAmount", glvWithdrawal.minShortTokenAmount());
        eventData.uintItems.setItem(3, "updatedAtTime", glvWithdrawal.updatedAtTime());
        eventData.uintItems.setItem(4, "executionFee", glvWithdrawal.executionFee());
        eventData.uintItems.setItem(5, "callbackGasLimit", glvWithdrawal.callbackGasLimit());

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "shouldUnwrapNativeToken", glvWithdrawal.shouldUnwrapNativeToken());

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.bytes32Items.initArrayItems(1);
        eventData.bytes32Items.setItem(0, "dataList", glvWithdrawal.dataList());

        eventEmitter.emitEventLog2("GlvWithdrawalCreated", key, Cast.toBytes32(glvWithdrawal.account()), eventData);
    }

    function emitGlvWithdrawalExecuted(EventEmitter eventEmitter, bytes32 key, address account) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventEmitter.emitEventLog2("GlvWithdrawalExecuted", key, Cast.toBytes32(account), eventData);
    }

    function emitGlvWithdrawalCancelled(
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

        eventEmitter.emitEventLog2("GlvWithdrawalCancelled", key, Cast.toBytes32(account), eventData);
    }
}
