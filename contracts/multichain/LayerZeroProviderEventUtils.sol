// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import { EventEmitter } from "../event/EventEmitter.sol";
import { EventUtils } from "../event/EventUtils.sol";
import { Cast } from "../utils/Cast.sol";

/**
 * @title LayerZeroProviderEventUtils
 */
library LayerZeroProviderEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;

    function emitComposedMessageReceived(
        EventEmitter eventEmitter,
        uint256 sourceChainId,
        address account,
        address from,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(3);
        eventData.addressItems.setItem(0, "account", account);
        eventData.addressItems.setItem(1, "from", from);
        eventData.addressItems.setItem(2, "executor", executor);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "sourceChainId", sourceChainId);
        
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "guid", guid);

        eventData.bytesItems.initItems(2);
        eventData.bytesItems.setItem(0, "message", message);
        eventData.bytesItems.setItem(1, "extraData", extraData);

        eventEmitter.emitEventLog2("MessageComposedReceived", bytes32(sourceChainId), Cast.toBytes32(account), eventData);
    }

    function emitWithdrawalReceipt(
        EventEmitter eventEmitter,
        uint256 sourceChainId,
        address account,
        bytes32 guid,
        uint64 nonce,
        uint256 nativeFee,
        uint256 lzTokenFee,
        uint256 amountSentLD,
        uint256 amountReceivedLD
    ) internal {
        EventUtils.EventLogData memory eventData;
        
        eventData.uintItems.initItems(6);
        eventData.uintItems.setItem(0, "nonce", uint256(nonce));
        eventData.uintItems.setItem(1, "nativeFee", nativeFee);
        eventData.uintItems.setItem(2, "lzTokenFee", lzTokenFee);
        eventData.uintItems.setItem(3, "amountSentLD", amountSentLD);
        eventData.uintItems.setItem(4, "amountReceivedLD", amountReceivedLD);
        eventData.uintItems.setItem(5, "sourceChainId", sourceChainId);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "guid", guid);
        
        eventEmitter.emitEventLog2("WithdrawalReceipt", bytes32(sourceChainId), Cast.toBytes32(account), eventData);
    }
}
