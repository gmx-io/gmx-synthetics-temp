// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../event/EventUtils.sol";
import "../utils/Cast.sol";

import "./Deposit.sol";
import "../pricing/ISwapPricingUtils.sol";

library DepositEventUtils {
    using Deposit for Deposit.Props;

    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    function emitDepositCreated(
        EventEmitter eventEmitter,
        bytes32 key,
        Deposit.Props memory deposit,
        Deposit.DepositType depositType
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(7);
        eventData.addressItems.setItem(0, "account", deposit.account());
        eventData.addressItems.setItem(1, "receiver", deposit.receiver());
        eventData.addressItems.setItem(2, "callbackContract", deposit.callbackContract());
        eventData.addressItems.setItem(3, "market", deposit.market());
        eventData.addressItems.setItem(4, "initialLongToken", deposit.initialLongToken());
        eventData.addressItems.setItem(5, "initialShortToken", deposit.initialShortToken());
        eventData.addressItems.setItem(6, "uiFeeReceiver", deposit.uiFeeReceiver());

        eventData.addressItems.initArrayItems(2);
        eventData.addressItems.setItem(0, "longTokenSwapPath", deposit.longTokenSwapPath());
        eventData.addressItems.setItem(1, "shortTokenSwapPath", deposit.shortTokenSwapPath());

        eventData.uintItems.initItems(7);
        eventData.uintItems.setItem(0, "initialLongTokenAmount", deposit.initialLongTokenAmount());
        eventData.uintItems.setItem(1, "initialShortTokenAmount", deposit.initialShortTokenAmount());
        eventData.uintItems.setItem(2, "minMarketTokens", deposit.minMarketTokens());
        eventData.uintItems.setItem(3, "updatedAtTime", deposit.updatedAtTime());
        eventData.uintItems.setItem(4, "executionFee", deposit.executionFee());
        eventData.uintItems.setItem(5, "callbackGasLimit", deposit.callbackGasLimit());
        eventData.uintItems.setItem(6, "depositType", uint256(depositType));

        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "shouldUnwrapNativeToken", deposit.shouldUnwrapNativeToken());

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventEmitter.emitEventLog2(
            "DepositCreated",
            key,
            Cast.toBytes32(deposit.account()),
            eventData
        );
    }

    function emitDepositExecuted(
        EventEmitter eventEmitter,
        bytes32 key,
        address account,
        uint256 longTokenAmount,
        uint256 shortTokenAmount,
        uint256 receivedMarketTokens,
        ISwapPricingUtils.SwapPricingType swapPricingType
    ) external {
        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "key", key);

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(4);
        eventData.uintItems.setItem(0, "longTokenAmount", longTokenAmount);
        eventData.uintItems.setItem(1, "shortTokenAmount", shortTokenAmount);
        eventData.uintItems.setItem(2, "receivedMarketTokens", receivedMarketTokens);
        eventData.uintItems.setItem(3, "swapPricingType", uint256(swapPricingType));

        eventEmitter.emitEventLog2(
            "DepositExecuted",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }

    function emitDepositCancelled(
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
            "DepositCancelled",
            key,
            Cast.toBytes32(account),
            eventData
        );
    }
}
