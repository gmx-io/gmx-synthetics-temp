// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/Keys.sol";
import "../data/DataStore.sol";

import "./Shift.sol";

library ShiftStoreUtils {
    using Shift for Shift.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant RECEIVER = keccak256(abi.encode("RECEIVER"));
    bytes32 public constant CALLBACK_CONTRACT = keccak256(abi.encode("CALLBACK_CONTRACT"));
    bytes32 public constant UI_FEE_RECEIVER = keccak256(abi.encode("UI_FEE_RECEIVER"));
    bytes32 public constant FROM_MARKET = keccak256(abi.encode("FROM_MARKET"));
    bytes32 public constant TO_MARKET = keccak256(abi.encode("TO_MARKET"));

    bytes32 public constant MARKET_TOKEN_AMOUNT = keccak256(abi.encode("MARKET_TOKEN_AMOUNT"));
    bytes32 public constant MIN_MARKET_TOKENS = keccak256(abi.encode("MIN_MARKET_TOKENS"));
    bytes32 public constant UPDATED_AT_TIME = keccak256(abi.encode("UPDATED_AT_TIME"));
    bytes32 public constant EXECUTION_FEE = keccak256(abi.encode("EXECUTION_FEE"));
    bytes32 public constant CALLBACK_GAS_LIMIT = keccak256(abi.encode("CALLBACK_GAS_LIMIT"));

    bytes32 public constant DATA_LIST = keccak256(abi.encode("DATA_LIST"));

    function get(DataStore dataStore, bytes32 key) external view returns (Shift.Props memory) {
        Shift.Props memory shift;
        if (!dataStore.containsBytes32(Keys.SHIFT_LIST, key)) {
            return shift;
        }

        shift.setAccount(dataStore.getAddress(
            keccak256(abi.encode(key, ACCOUNT))
        ));

        shift.setReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, RECEIVER))
        ));

        shift.setCallbackContract(dataStore.getAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT))
        ));

        shift.setUiFeeReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER))
        ));

        shift.setFromMarket(dataStore.getAddress(
            keccak256(abi.encode(key, FROM_MARKET))
        ));

        shift.setToMarket(dataStore.getAddress(
            keccak256(abi.encode(key, TO_MARKET))
        ));

        shift.setMarketTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, MARKET_TOKEN_AMOUNT))
        ));

        shift.setMinMarketTokens(dataStore.getUint(
            keccak256(abi.encode(key, MIN_MARKET_TOKENS))
        ));

        shift.setUpdatedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        ));

        shift.setExecutionFee(dataStore.getUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        ));

        shift.setCallbackGasLimit(dataStore.getUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        ));

        shift.setDataList(dataStore.getBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        ));

        return shift;
    }

    function set(DataStore dataStore, bytes32 key, Shift.Props memory shift) external {
        dataStore.addBytes32(
            Keys.SHIFT_LIST,
            key
        );

        dataStore.addBytes32(
            Keys.accountShiftListKey(shift.account()),
            key
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, ACCOUNT)),
            shift.account()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, RECEIVER)),
            shift.receiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT)),
            shift.callbackContract()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER)),
            shift.uiFeeReceiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, FROM_MARKET)),
            shift.fromMarket()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, TO_MARKET)),
            shift.toMarket()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MARKET_TOKEN_AMOUNT)),
            shift.marketTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MIN_MARKET_TOKENS)),
            shift.minMarketTokens()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME)),
            shift.updatedAtTime()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, EXECUTION_FEE)),
            shift.executionFee()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT)),
            shift.callbackGasLimit()
        );

        dataStore.setBytes32Array(
            keccak256(abi.encode(key, DATA_LIST)),
            shift.dataList()
        );
    }

    function remove(DataStore dataStore, bytes32 key, address account) external {
        if (!dataStore.containsBytes32(Keys.SHIFT_LIST, key)) {
            revert Errors.ShiftNotFound(key);
        }

        dataStore.removeBytes32(
            Keys.SHIFT_LIST,
            key
        );

        dataStore.removeBytes32(
            Keys.accountShiftListKey(account),
            key
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, ACCOUNT))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, RECEIVER))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, FROM_MARKET))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, TO_MARKET))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, MARKET_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, MIN_MARKET_TOKENS))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        );

        dataStore.removeBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        );
    }

    function getShiftCount(DataStore dataStore) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.SHIFT_LIST);
    }

    function getShiftKeys(DataStore dataStore, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.SHIFT_LIST, start, end);
    }

    function getAccountShiftCount(DataStore dataStore, address account) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.accountShiftListKey(account));
    }

    function getAccountShiftKeys(DataStore dataStore, address account, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.accountShiftListKey(account), start, end);
    }
}
