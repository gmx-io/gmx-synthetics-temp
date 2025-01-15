// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import { StrictBank } from "../bank/StrictBank.sol";
import { RoleStore } from "../role/RoleStore.sol";
import { DataStore } from "../data/DataStore.sol";

/**
 * @title MultichainVault
 * @dev Vault for crosschain deposits
 */
contract MultichainVault is StrictBank {
    constructor(RoleStore _roleStore, DataStore _dataStore) StrictBank(_roleStore, _dataStore) {}
}
