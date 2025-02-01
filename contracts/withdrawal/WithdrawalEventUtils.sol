// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";

import "./Withdrawal.sol";
import "../pricing/ISwapPricingUtils.sol";

library WithdrawalEventUtils {
    using Withdrawal for Withdrawal.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    function emitWithdrawalCreated(
        EventEmitter eventEmitter,
        bytes32 key,
        Withdrawal.Props memory withdrawal,
        Withdrawal.WithdrawalType withdrawalType
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(5);
        eventData.addressItems.setItem(0, "account", withdrawal.account());
        eventData.addressItems.setItem(1, "receiver", withdrawal.receiver());
        eventData.addressItems.setItem(2, "callbackContract", withdrawal.callbackContract());
        eventData.addressItems.setItem(3, "market", withdrawal.market());
        eventData.addressItems.setItem(4, "uiFeeReceiver", withdrawal.uiFeeReceiver());

        eventData.addressItems.initArrayItems(2);
        eventData.addressItems.setItem(0, "longTokenSwapPath", withdrawal.longTokenSwapPath());
        eventData.addressItems.setItem(1, "shortTokenSwapPath", withdrawal.shortTokenSwapPath());

        eventData.uintItems.initItems(7);
        eventData.uintItems.setItem(0, "marketTokenAmount", withdrawal.marketTokenAmount());
        eventData.uintItems.setItem(1, "minLongTokenAmount", withdrawal.minLongTokenAmount());
        eventData.uintItems.setItem(2, "minShortTokenAmount", withdrawal.minShortTokenAmount());
        eventData.uintItems.setItem(3, "updatedAtTime", withdrawal.updatedAtTime());
        eventData.uintItems.setItem(4, "executionFee", withdrawal.executionFee());
        eventData.uintItems.setItem(5, "callbackGasLimit", withdrawal.callbackGasLimit());
        eventData.uintItems.setItem(6, "withdrawalType", uint256(withdrawalType));

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "shouldUnwrapNativeToken", withdrawal.shouldUnwrapNativeToken());

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventEmitter.emitEventLog2(
            "WithdrawalCreated",
            key,
            Cast.toBytes32(withdrawal.account()),
            eventData
        );
    }

    function emitWithdrawalExecuted(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "swapPricingType", uint256(swapPricingType));

        eventEmitter.emitEventLog2(
            "WithdrawalExecuted",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitWithdrawalCancelled(
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
            "WithdrawalCancelled",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }
}
