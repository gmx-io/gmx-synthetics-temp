// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../event/EventEmitter.sol";
import "../../event/EventUtils.sol";
import "../../utils/Cast.sol";

import "./GlvDeposit.sol";

library GlvDepositEventUtils {
    using GlvDeposit for GlvDeposit.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    function emitGlvDepositCreated(
        EventEmitter eventEmitter,
        bytes32 key,
        GlvDeposit.Props memory glvDeposit
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(8);
        eventData.addressItems.setItem(0, "account", glvDeposit.account());
        eventData.addressItems.setItem(1, "receiver", glvDeposit.receiver());
        eventData.addressItems.setItem(2, "callbackContract", glvDeposit.callbackContract());
        eventData.addressItems.setItem(3, "market", glvDeposit.market());
        eventData.addressItems.setItem(4, "glv", glvDeposit.glv());
        eventData.addressItems.setItem(5, "initialLongToken", glvDeposit.initialLongToken());
        eventData.addressItems.setItem(6, "initialShortToken", glvDeposit.initialShortToken());
        eventData.addressItems.setItem(7, "uiFeeReceiver", glvDeposit.uiFeeReceiver());

        eventData.addressItems.initArrayItems(2);
        eventData.addressItems.setItem(0, "longTokenSwapPath", glvDeposit.longTokenSwapPath());
        eventData.addressItems.setItem(1, "shortTokenSwapPath", glvDeposit.shortTokenSwapPath());

        eventData.uintItems.initItems(7);
        eventData.uintItems.setItem(0, "initialLongTokenAmount", glvDeposit.initialLongTokenAmount());
        eventData.uintItems.setItem(1, "initialShortTokenAmount", glvDeposit.initialShortTokenAmount());
        eventData.uintItems.setItem(2, "minGlvTokens", glvDeposit.minGlvTokens());
        eventData.uintItems.setItem(3, "updatedAtTime", glvDeposit.updatedAtTime());
        eventData.uintItems.setItem(4, "executionFee", glvDeposit.executionFee());
        eventData.uintItems.setItem(5, "callbackGasLimit", glvDeposit.callbackGasLimit());
        eventData.uintItems.setItem(6, "marketTokenAmount", glvDeposit.marketTokenAmount());

        eventData.boolItems.initItems(2);
        eventData.boolItems.setItem(0, "shouldUnwrapNativeToken", glvDeposit.shouldUnwrapNativeToken());
        eventData.boolItems.setItem(1, "isMarketTokenDeposit", glvDeposit.isMarketTokenDeposit());

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.bytes32Items.initArrayItems(1);
        eventData.bytes32Items.setItem(0, "dataList", glvDeposit.dataList());

        eventEmitter.emitEventLog2(
            "GlvDepositCreated",
            key,
            Cast.toBytes32(glvDeposit.account()),
            eventData
        );
    }

    function emitGlvDepositExecuted(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        uint256 receivedGlvTokens
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "receivedGlvTokens", receivedGlvTokens);

        eventEmitter.emitEventLog2(
            "GlvDepositExecuted",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitGlvDepositCancelled(
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
            "GlvDepositCancelled",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }
}
