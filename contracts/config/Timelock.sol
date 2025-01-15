// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../role/RoleModule.sol";
import "../event/EventEmitter.sol";
import "../utils/BasicMulticall.sol";
import "../utils/Precision.sol";
import "../oracle/OracleStore.sol";
import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../chain/Chain.sol";

// @title Timelock
contract Timelock is ReentrancyGuard, RoleModule, BasicMulticall {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.UintItems;
    using EventUtils for EventUtils.IntItems;
    using EventUtils for EventUtils.BoolItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;
    using EventUtils for EventUtils.StringItems;

    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableValues for EnumerableSet.Bytes32Set;

    uint256 public constant MAX_TIMELOCK_DELAY = 5 days;

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    OracleStore public immutable oracleStore;
    uint256 public timelockDelay;

    mapping (bytes32 => uint256) public pendingActions;
    EnumerableSet.Bytes32Set internal pendingActionsList;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        OracleStore _oracleStore,
        uint256 _timelockDelay
    ) RoleModule(_roleStore) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        oracleStore = _oracleStore;
        timelockDelay = _timelockDelay;

        _validateTimelockDelay();
    }

    function getPendingActionsCount() internal view returns (uint256) {
        return pendingActionsList.length();
    }

    function getPendingActionsList(uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return pendingActionsList.valuesAt(start, end);
    }

    // @dev immediately revoke the role of an account
    // @param account the account to revoke the role for
    // @param roleKey the role to revoke
    function revokeRole(address account, bytes32 roleKey) external onlyTimelockMultisig nonReentrant {
        roleStore.revokeRole(account, roleKey);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "roleKey", roleKey);
        eventEmitter.emitEventLog(
            "RevokeRole",
            eventData
        );
    }

    // @dev increase the timelock delay
    // @param the new timelock delay
    function increaseTimelockDelay(uint256 _timelockDelay) external onlyTimelockAdmin nonReentrant {
        if (_timelockDelay <= timelockDelay) {
            revert Errors.InvalidTimelockDelay(_timelockDelay);
        }

        timelockDelay = _timelockDelay;

        _validateTimelockDelay();

        EventUtils.EventLogData memory eventData;
        eventData.uintItems.initItems(1);
        eventData.uintItems.setItem(0, "_timelockDelay", _timelockDelay);
        eventEmitter.emitEventLog(
            "IncreaseTimelockDelay",
            eventData
        );
    }

    function setOracleProviderEnabled(address provider, bool value) external onlyTimelockMultisig nonReentrant {
        dataStore.setBool(Keys.isOracleProviderEnabledKey(provider), value);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "provider", provider);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "value", value);
        eventEmitter.emitEventLog(
            "SetOracleProviderEnabled",
            eventData
        );
    }

    function signalSetOracleProviderForToken(address token, address provider) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setOracleProviderForTokenKey(token, provider);
        _signalPendingAction(actionKey, "setOracleProviderForToken");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "provider", provider);
        eventEmitter.emitEventLog(
            "SignalSetOracleProviderForToken",
            eventData
        );
    }

    function setOracleProviderForTokenAfterSignal(address token, address provider) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setOracleProviderForTokenKey(token, provider);
        _validateAndClearAction(actionKey, "setOracleProviderForToken");

        dataStore.setAddress(Keys.oracleProviderForTokenKey(token), provider);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "provider", provider);
        eventEmitter.emitEventLog(
            "SetOracleProviderForToken",
            eventData
        );
    }

    function signalSetOracleProviderEnabled(address provider, bool value) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setOracleProviderEnabledKey(provider, value);
        _signalPendingAction(actionKey, "setOracleProviderEnabled");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "provider", provider);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "value", value);
        eventEmitter.emitEventLog(
            "SignalSetOracleProviderEnabled",
            eventData
        );
    }

    function setOracleProviderEnabledAfterSignal(address provider, bool value) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setOracleProviderEnabledKey(provider, value);
        _validateAndClearAction(actionKey, "setOracleProviderEnabled");

        dataStore.setBool(Keys.isOracleProviderEnabledKey(provider), value);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "provider", provider);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "value", value);
        eventEmitter.emitEventLog(
            "SetOracleProviderEnabled",
            eventData
        );
    }

    function signalSetAtomicOracleProvider(address provider, bool value) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setAtomicOracleProviderKey(provider, value);
        _signalPendingAction(actionKey, "setAtomicOracleProvider");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "provider", provider);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "value", value);
        eventEmitter.emitEventLog(
            "SignalSetAtomicOracleProvider",
            eventData
        );
    }

    function setAtomicOracleProviderAfterSignal(address provider, bool value) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setAtomicOracleProviderKey(provider, value);
        _validateAndClearAction(actionKey, "setAtomicOracleProvider");

        dataStore.setBool(Keys.isAtomicOracleProviderKey(provider), value);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "provider", provider);
        eventData.boolItems.initItems(1);
        eventData.boolItems.setItem(0, "value", value);
        eventEmitter.emitEventLog(
            "SetAtomicOracleProvider",
            eventData
        );
    }

    function signalAddOracleSigner(address account) external onlyTimelockAdmin nonReentrant {
        if (account == address(0)) {
            revert Errors.InvalidOracleSigner(account);
        }

        bytes32 actionKey = _addOracleSignerActionKey(account);
        _signalPendingAction(actionKey, "addOracleSigner");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventEmitter.emitEventLog1(
            "SignalAddOracleSigner",
            actionKey,
            eventData
        );
    }

    function addOracleSignerAfterSignal(address account) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _addOracleSignerActionKey(account);
        _validateAndClearAction(actionKey, "addOracleSigner");

        oracleStore.addSigner(account);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventEmitter.emitEventLog1(
            "AddOracleSigner",
            actionKey,
            eventData
        );
    }

    function signalRemoveOracleSigner(address account) external onlyTimelockAdmin nonReentrant {
        if (account == address(0)) {
            revert Errors.InvalidOracleSigner(account);
        }

        bytes32 actionKey = _removeOracleSignerActionKey(account);
        _signalPendingAction(actionKey, "removeOracleSigner");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventEmitter.emitEventLog1(
            "SignalRemoveOracleSigner",
            actionKey,
            eventData
        );
    }

    function removeOracleSignerAfterSignal(address account) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _removeOracleSignerActionKey(account);
        _validateAndClearAction(actionKey, "removeOracleSigner");

        oracleStore.removeSigner(account);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventEmitter.emitEventLog1(
            "RemoveOracleSigner",
            actionKey,
            eventData
        );
    }

    // @dev signal setting of the fee receiver
    // @param account the new fee receiver
    function signalSetFeeReceiver(address account) external onlyTimelockAdmin nonReentrant {
        if (account == address(0)) {
            revert Errors.InvalidFeeReceiver(account);
        }

        bytes32 actionKey = _setFeeReceiverActionKey(account);
        _signalPendingAction(actionKey, "setFeeReceiver");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventEmitter.emitEventLog1(
            "SignalSetFeeReceiver",
            actionKey,
            eventData
        );
    }

    // @dev set the fee receiver
    // @param account the new fee receiver
    function setFeeReceiverAfterSignal(address account) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setFeeReceiverActionKey(account);
        _validateAndClearAction(actionKey, "setFeeReceiver");

        dataStore.setAddress(Keys.FEE_RECEIVER, account);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventEmitter.emitEventLog1(
            "SetFeeReceiver",
            actionKey,
            eventData
        );
    }

    // @dev signal granting of a role
    // @param account the account to grant the role
    // @param roleKey the role to grant
    function signalGrantRole(address account, bytes32 roleKey) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _grantRoleActionKey(account, roleKey);
        _signalPendingAction(actionKey, "grantRole");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "roleKey", roleKey);
        eventEmitter.emitEventLog1(
            "SignalGrantRole",
            actionKey,
            eventData
        );
    }

    // @dev grant a role
    // @param account the account to grant the role
    // @param roleKey the role to grant
    function grantRoleAfterSignal(address account, bytes32 roleKey) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _grantRoleActionKey(account, roleKey);
        _validateAndClearAction(actionKey, "grantRole");

        roleStore.grantRole(account, roleKey);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "roleKey", roleKey);
        eventEmitter.emitEventLog1(
            "GrantRole",
            actionKey,
            eventData
        );
    }

    // @dev signal revoking of a role
    // @param account the account to revoke the role for
    // @param roleKey the role to revoke
    function signalRevokeRole(address account, bytes32 roleKey) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _revokeRoleActionKey(account, roleKey);
        _signalPendingAction(actionKey, "revokeRole");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "roleKey", roleKey);
        eventEmitter.emitEventLog1(
            "SignalRevokeRole",
            actionKey,
            eventData
        );
    }

    // @dev revoke a role
    // @param account the account to revoke the role for
    // @param roleKey the role to revoke
    function revokeRoleAfterSignal(address account, bytes32 roleKey) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _revokeRoleActionKey(account, roleKey);
        _validateAndClearAction(actionKey, "revokeRole");

        roleStore.revokeRole(account, roleKey);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "account", account);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "roleKey", roleKey);
        eventEmitter.emitEventLog1(
            "RevokeRole",
            actionKey,
            eventData
        );
    }

    // @dev signal setting of a price feed
    // @param token the token to set the price feed for
    // @param priceFeed the address of the price feed
    // @param priceFeedMultiplier the multiplier to apply to the price feed results
    // @param stablePrice the stable price to set a range for the price feed results
    function signalSetPriceFeed(
        address token,
        address priceFeed,
        uint256 priceFeedMultiplier,
        uint256 priceFeedHeartbeatDuration,
        uint256 stablePrice
    ) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setPriceFeedActionKey(
            token,
            priceFeed,
            priceFeedMultiplier,
            priceFeedHeartbeatDuration,
            stablePrice
        );

        _signalPendingAction(actionKey, "setPriceFeed");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "priceFeed", priceFeed);
        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "priceFeedMultiplier", priceFeedMultiplier);
        eventData.uintItems.setItem(1, "priceFeedHeartbeatDuration", priceFeedHeartbeatDuration);
        eventData.uintItems.setItem(2, "stablePrice", stablePrice);
        eventEmitter.emitEventLog1(
            "SignalSetPriceFeed",
            actionKey,
            eventData
        );
    }

    // @dev sets a price feed
    // @param token the token to set the price feed for
    // @param priceFeed the address of the price feed
    // @param priceFeedMultiplier the multiplier to apply to the price feed results
    // @param stablePrice the stable price to set a range for the price feed results
    function setPriceFeedAfterSignal(
        address token,
        address priceFeed,
        uint256 priceFeedMultiplier,
        uint256 priceFeedHeartbeatDuration,
        uint256 stablePrice
    ) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setPriceFeedActionKey(
            token,
            priceFeed,
            priceFeedMultiplier,
            priceFeedHeartbeatDuration,
            stablePrice
        );

        _validateAndClearAction(actionKey, "setPriceFeed");

        dataStore.setAddress(Keys.priceFeedKey(token), priceFeed);
        dataStore.setUint(Keys.priceFeedMultiplierKey(token), priceFeedMultiplier);
        dataStore.setUint(Keys.priceFeedHeartbeatDurationKey(token), priceFeedHeartbeatDuration);
        dataStore.setUint(Keys.stablePriceKey(token), stablePrice);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(2);
        eventData.addressItems.setItem(0, "token", token);
        eventData.addressItems.setItem(1, "priceFeed", priceFeed);
        eventData.uintItems.initItems(3);
        eventData.uintItems.setItem(0, "priceFeedMultiplier", priceFeedMultiplier);
        eventData.uintItems.setItem(1, "priceFeedHeartbeatDuration", priceFeedHeartbeatDuration);
        eventData.uintItems.setItem(2, "stablePrice", stablePrice);
        eventEmitter.emitEventLog1(
            "SetPriceFeed",
            actionKey,
            eventData
        );
    }

    // @dev signal setting of a data stream feed
    // @param token the token to set the data stream feed for
    // @param feedId the ID of the data stream feed
    // @param dataStreamMultiplier the multiplier to apply to the data stream feed results
    // @param dataStreamSpreadReductionFactor the factor to apply to the data stream price spread
    function signalSetDataStream(
        address token,
        bytes32 feedId,
        uint256 dataStreamMultiplier,
        uint256 dataStreamSpreadReductionFactor
    ) external onlyTimelockAdmin nonReentrant {
        if (dataStreamSpreadReductionFactor > Precision.FLOAT_PRECISION) {
            revert Errors.ConfigValueExceedsAllowedRange(Keys.DATA_STREAM_SPREAD_REDUCTION_FACTOR, dataStreamSpreadReductionFactor);
        }

        bytes32 actionKey = _setDataStreamActionKey(
            token,
            feedId,
            dataStreamMultiplier,
            dataStreamSpreadReductionFactor
        );

        _signalPendingAction(actionKey, "setDataStream");

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "token", token);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "feedId", feedId);
        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "dataStreamMultiplier", dataStreamMultiplier);
        eventData.uintItems.setItem(1, "dataStreamSpreadReductionFactor", dataStreamSpreadReductionFactor);
        eventEmitter.emitEventLog1(
            "SignalSetDataStream",
            actionKey,
            eventData
        );
    }

    // @dev sets a data stream feed
    // @param token the token to set the data stream feed for
    // @param feedId the ID of the data stream feed
    // @param dataStreamMultiplier the multiplier to apply to the data stream feed results
    // @param dataStreamMultiplier the factor to apply to the data stream price spread
    function setDataStreamAfterSignal(
        address token,
        bytes32 feedId,
        uint256 dataStreamMultiplier,
        uint256 dataStreamSpreadReductionFactor
    ) external onlyTimelockAdmin nonReentrant {
        bytes32 actionKey = _setDataStreamActionKey(
            token,
            feedId,
            dataStreamMultiplier,
            dataStreamSpreadReductionFactor
        );

        _validateAndClearAction(actionKey, "setDataStream");

        dataStore.setBytes32(Keys.dataStreamIdKey(token), feedId);
        dataStore.setUint(Keys.dataStreamMultiplierKey(token), dataStreamMultiplier);
        dataStore.setUint(Keys.dataStreamSpreadReductionFactorKey(token), dataStreamSpreadReductionFactor);

        EventUtils.EventLogData memory eventData;
        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "token", token);
        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "feedId", feedId);
        eventData.uintItems.initItems(2);
        eventData.uintItems.setItem(0, "dataStreamMultiplier", dataStreamMultiplier);
        eventData.uintItems.setItem(1, "dataStreamSpreadReductionFactor", dataStreamSpreadReductionFactor);
        eventEmitter.emitEventLog1(
            "SetDataStream",
            actionKey,
            eventData
        );
    }

    // @dev cancels a previously signalled pending action
    // @param actionKey the key of the action to cancel
    function cancelAction(bytes32 actionKey) external onlyTimelockAdmin nonReentrant {
        _clearAction(actionKey, "cancelAction");
    }

    // @dev signal a pending action
    // @param actionKey the key of the action
    // @param actionLabel a label for the action
    function _signalPendingAction(bytes32 actionKey, string memory actionLabel) internal {
        if (pendingActions[actionKey] != 0) {
            revert Errors.ActionAlreadySignalled();
        }

        pendingActions[actionKey] = Chain.currentTimestamp() + timelockDelay;
        pendingActionsList.add(actionKey);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "actionKey", actionKey);

        eventData.stringItems.initItems(1);
        eventData.stringItems.setItem(0, "actionLabel", actionLabel);

        eventEmitter.emitEventLog1(
            "SignalPendingAction",
            actionKey,
            eventData
        );
    }

    function _setOracleProviderForTokenKey(address token, address provider) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("setOracleProviderForToken", token, provider));
    }

    function _setOracleProviderEnabledKey(address provider, bool value) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("setOracleProviderEnabled", provider, value));
    }

    function _setAtomicOracleProviderKey(address provider, bool value) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("setAtomicOracleProvider", provider, value));
    }

    function _addOracleSignerActionKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("addOracleSigner", account));
    }

    function _removeOracleSignerActionKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("removeOracleSigner", account));
    }

    function _setFeeReceiverActionKey(address account) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("setFeeReceiver", account));
    }

    function _grantRoleActionKey(address account, bytes32 roleKey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("grantRole", account, roleKey));
    }

    function _revokeRoleActionKey(address account, bytes32 roleKey) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("revokeRole", account, roleKey));
    }

    function _setPriceFeedActionKey(
        address token,
        address priceFeed,
        uint256 priceFeedMultiplier,
        uint256 priceFeedHeartbeatDuration,
        uint256 stablePrice
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "setPriceFeed",
            token,
            priceFeed,
            priceFeedMultiplier,
            priceFeedHeartbeatDuration,
            stablePrice
        ));
    }

    function _setDataStreamActionKey(
        address token,
        bytes32 feedId,
        uint256 dataStreamMultiplier,
        uint256 dataStreamSpreadReductionFactor
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "setDataStream",
            token,
            feedId,
            dataStreamMultiplier,
            dataStreamSpreadReductionFactor
        ));
    }

    // @dev validate that the action has been signalled and sufficient time has
    // passed, clear the action after
    function _validateAndClearAction(bytes32 actionKey, string memory actionLabel) internal {
        _validateAction(actionKey);
        _clearAction(actionKey, actionLabel);
    }

    // @dev validate that the action has been signalled and sufficient time has passed
    function _validateAction(bytes32 actionKey) internal view {
        if (pendingActions[actionKey] == 0) {
            revert Errors.ActionNotSignalled();
        }

        if (pendingActions[actionKey] > Chain.currentTimestamp()) {
            revert Errors.SignalTimeNotYetPassed(pendingActions[actionKey]);
        }
    }

    // @dev clear a previously signalled action
    function _clearAction(bytes32 actionKey, string memory actionLabel) internal {
        if (pendingActions[actionKey] == 0) {
            revert Errors.ActionNotSignalled();
        }
        delete pendingActions[actionKey];
        pendingActionsList.remove(actionKey);

        EventUtils.EventLogData memory eventData;

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "actionKey", actionKey);

        eventData.stringItems.initItems(1);
        eventData.stringItems.setItem(0, "actionLabel", actionLabel);

        eventEmitter.emitEventLog1(
            "ClearPendingAction",
            actionKey,
            eventData
        );
    }

    function _validateTimelockDelay() internal view {
        if (timelockDelay > MAX_TIMELOCK_DELAY) {
            revert Errors.MaxTimelockDelayExceeded(timelockDelay);
        }
    }
}
