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
        address virtualAccount,
        uint256 amount,
        uint256 sourceChainId
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "virtualAccount", virtualAccount);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "amount", amount);
        eventData.uintItems.setItem(1, "sourceChainId", sourceChainId);

        eventEmitter.emitEventLog1("MultichainDeposit", Cast.toBytes32(virtualAccount), eventData);
    }

    function emitMultichainMessage(
        EventEmitter eventEmitter,
        address virtualAccount,
        uint256 sourceChainId
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "virtualAccount", virtualAccount);

        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "sourceChainId", sourceChainId);

        eventEmitter.emitEventLog1("MultichainMessage", Cast.toBytes32(virtualAccount), eventData);
    }

    function emitMultichainWithdrawal(
        EventEmitter eventEmitter,
        address token,
        address virtualAccount,
        uint256 amount,
        uint256 sourceChainId
    ) internal {
        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "virtualAccount", virtualAccount);

        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "amount", amount);
        eventData.uintItems.setItem(1, "sourceChainId", sourceChainId);

        eventEmitter.emitEventLog1("MultichainWithdrawal", Cast.toBytes32(virtualAccount), eventData);
    }
}
