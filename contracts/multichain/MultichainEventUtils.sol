// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import { EventEmitter } from "../event/EventEmitter.sol";
import { EventUtils } from "../event/EventUtils.sol";
import { Cast } from "../utils/Cast.sol";

/**
 * @title MultichainEventUtils
 */
library MultichainEventUtils {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;

    function emitMultichainDeposit(
        EventEmitter eventEmitter,
        address token,
        address account,
        uint256 amount,
        uint256 sourceChainId
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "account", account);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "amount", amount);
        eventData.uintItems.setItem(1, "sourceChainId", sourceChainId);

        eventEmitter.emitEventLog2("MultichainDeposit", bytes32(sourceChainId), Cast.toBytes32(account), eventData);
    }

    function emitMultichainMessage(
        EventEmitter eventEmitter,
        address account,
        uint256 sourceChainId
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "sourceChainId", sourceChainId);

        eventEmitter.emitEventLog1("MultichainMessage", Cast.toBytes32(account), eventData);
    }

    function emitMultichainWithdrawal(
        EventEmitter eventEmitter,
        address token,
        address account,
        uint256 amount,
        uint256 sourceChainId
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "account", account);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "amount", amount);
        eventData.uintItems.setItem(1, "sourceChainId", sourceChainId);

        eventEmitter.emitEventLog2("MultichainWithdrawal", bytes32(sourceChainId), Cast.toBytes32(account), eventData);
    }
}
