// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../event/EventEmitter.sol";
import "../oracle/Oracle.sol";
import "../oracle/OracleModule.sol";
import "../role/RoleModule.sol";
import "../utils/GlobalReentrancyGuard.sol";
import "../error/ErrorUtils.sol";
import "../feature/FeatureUtils.sol";

contract BaseHandler is RoleModule, GlobalReentrancyGuard, OracleModule {
    EventEmitter public immutable eventEmitter;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle
    ) RoleModule(_roleStore) GlobalReentrancyGuard(_dataStore) OracleModule(_oracle) {
        eventEmitter = _eventEmitter;
    }

    receive() external payable {
        address wnt = dataStore.getAddress(Keys.WNT);
        if (msg.sender != wnt) {
            revert Errors.InvalidNativeTokenSender(msg.sender);
        }
    }

    function validateRequestCancellation(
        uint256 createdAtTime,
        string memory requestType
    ) internal view {
        uint256 requestExpirationTime = dataStore.getUint(Keys.REQUEST_EXPIRATION_TIME);
        uint256 requestAge = Chain.currentTimestamp() - createdAtTime;
        if (requestAge < requestExpirationTime) {
            revert Errors.RequestNotYetCancellable(requestAge, requestExpirationTime, requestType);
        }
    }

    function validateNonKeeperError(bytes4 errorSelector, bytes memory reasonBytes) internal pure {
        if (
            OracleUtils.isOracleError(errorSelector) ||
            errorSelector == Errors.DisabledFeature.selector ||
            errorSelector == Errors.InsufficientGasLeftForCallback.selector ||
            errorSelector == Errors.InsufficientGasForCancellation.selector
        ) {
            ErrorUtils.revertWithCustomError(reasonBytes);
        }
    }

    function validateDataListLength(uint256 dataLength) internal view {
        uint256 maxDataLength = dataStore.getUint(Keys.MAX_DATA_LENGTH);
        if (dataLength > maxDataLength) {
            revert Errors.MaxDataListLengthExceeded(dataLength, maxDataLength);
        }
    }
}
