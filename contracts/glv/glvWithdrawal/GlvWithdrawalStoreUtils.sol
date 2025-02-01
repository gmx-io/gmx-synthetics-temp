// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../data/Keys.sol";
import "../../data/DataStore.sol";

import "./GlvWithdrawal.sol";

/**
 * @title GlvWithdrawalStoreUtils
 * @dev Library for withdrawal storage functions
 */
library GlvWithdrawalStoreUtils {
    using GlvWithdrawal for GlvWithdrawal.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant RECEIVER = keccak256(abi.encode("RECEIVER"));
    bytes32 public constant CALLBACK_CONTRACT = keccak256(abi.encode("CALLBACK_CONTRACT"));
    bytes32 public constant UI_FEE_RECEIVER = keccak256(abi.encode("UI_FEE_RECEIVER"));
    bytes32 public constant MARKET = keccak256(abi.encode("MARKET"));
    bytes32 public constant GLV = keccak256(abi.encode("GLV"));
    bytes32 public constant LONG_TOKEN_SWAP_PATH = keccak256(abi.encode("LONG_TOKEN_SWAP_PATH"));
    bytes32 public constant SHORT_TOKEN_SWAP_PATH = keccak256(abi.encode("SHORT_TOKEN_SWAP_PATH"));

    bytes32 public constant GLV_TOKEN_AMOUNT = keccak256(abi.encode("GLV_TOKEN_AMOUNT"));
    bytes32 public constant MIN_LONG_TOKEN_AMOUNT = keccak256(abi.encode("MIN_LONG_TOKEN_AMOUNT"));
    bytes32 public constant MIN_SHORT_TOKEN_AMOUNT = keccak256(abi.encode("MIN_SHORT_TOKEN_AMOUNT"));
    bytes32 public constant UPDATED_AT_TIME = keccak256(abi.encode("UPDATED_AT_TIME"));
    bytes32 public constant EXECUTION_FEE = keccak256(abi.encode("EXECUTION_FEE"));
    bytes32 public constant CALLBACK_GAS_LIMIT = keccak256(abi.encode("CALLBACK_GAS_LIMIT"));

    bytes32 public constant SHOULD_UNWRAP_NATIVE_TOKEN = keccak256(abi.encode("SHOULD_UNWRAP_NATIVE_TOKEN"));

    bytes32 public constant DATA_LIST = keccak256(abi.encode("DATA_LIST"));

    function get(DataStore dataStore, bytes32 key) external view returns (GlvWithdrawal.Props memory) {
        GlvWithdrawal.Props memory withdrawal;
        if (!dataStore.containsBytes32(Keys.GLV_WITHDRAWAL_LIST, key)) {
            return withdrawal;
        }

        withdrawal.setAccount(dataStore.getAddress(
            keccak256(abi.encode(key, ACCOUNT))
        ));

        withdrawal.setReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, RECEIVER))
        ));

        withdrawal.setCallbackContract(dataStore.getAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT))
        ));

        withdrawal.setUiFeeReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER))
        ));

        withdrawal.setMarket(dataStore.getAddress(
            keccak256(abi.encode(key, MARKET))
        ));

        withdrawal.setGlv(dataStore.getAddress(
            keccak256(abi.encode(key, GLV))
        ));

        withdrawal.setLongTokenSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH))
        ));

        withdrawal.setShortTokenSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH))
        ));

        withdrawal.setGlvTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, GLV_TOKEN_AMOUNT))
        ));

        withdrawal.setMinLongTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, MIN_LONG_TOKEN_AMOUNT))
        ));

        withdrawal.setMinShortTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, MIN_SHORT_TOKEN_AMOUNT))
        ));

        withdrawal.setUpdatedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        ));

        withdrawal.setExecutionFee(dataStore.getUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        ));

        withdrawal.setCallbackGasLimit(dataStore.getUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        ));

        withdrawal.setShouldUnwrapNativeToken(dataStore.getBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        ));

        withdrawal.setDataList(dataStore.getBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        ));

        return withdrawal;
    }

    function set(DataStore dataStore, bytes32 key, GlvWithdrawal.Props memory withdrawal) external {
        dataStore.addBytes32(
            Keys.GLV_WITHDRAWAL_LIST,
            key
        );

        dataStore.addBytes32(
            Keys.accountGlvWithdrawalListKey(withdrawal.account()),
            key
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, ACCOUNT)),
            withdrawal.account()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, RECEIVER)),
            withdrawal.receiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT)),
            withdrawal.callbackContract()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER)),
            withdrawal.uiFeeReceiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, MARKET)),
            withdrawal.market()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, GLV)),
            withdrawal.glv()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH)),
            withdrawal.longTokenSwapPath()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH)),
            withdrawal.shortTokenSwapPath()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, GLV_TOKEN_AMOUNT)),
            withdrawal.glvTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MIN_LONG_TOKEN_AMOUNT)),
            withdrawal.minLongTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MIN_SHORT_TOKEN_AMOUNT)),
            withdrawal.minShortTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME)),
            withdrawal.updatedAtTime()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, EXECUTION_FEE)),
            withdrawal.executionFee()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT)),
            withdrawal.callbackGasLimit()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN)),
            withdrawal.shouldUnwrapNativeToken()
        );

        dataStore.setBytes32Array(
            keccak256(abi.encode(key, DATA_LIST)),
            withdrawal.dataList()
        );
    }

    function remove(DataStore dataStore, bytes32 key, address account) external {
        if (!dataStore.containsBytes32(Keys.GLV_WITHDRAWAL_LIST, key)) {
            revert Errors.GlvWithdrawalNotFound(key);
        }

        dataStore.removeBytes32(
            Keys.GLV_WITHDRAWAL_LIST,
            key
        );

        dataStore.removeBytes32(
            Keys.accountGlvWithdrawalListKey(account),
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
            keccak256(abi.encode(key, MARKET))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, GLV))
        );

        dataStore.removeAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH))
        );

        dataStore.removeAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, GLV_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, MIN_LONG_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, MIN_SHORT_TOKEN_AMOUNT))
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

        dataStore.removeBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        );

        dataStore.removeBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        );
    }

    function getGlvWithdrawalCount(DataStore dataStore) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.GLV_WITHDRAWAL_LIST);
    }

    function getGlvWithdrawalKeys(DataStore dataStore, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.GLV_WITHDRAWAL_LIST, start, end);
    }

    function getAccountGlvWithdrawalCount(DataStore dataStore, address account) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.accountGlvWithdrawalListKey(account));
    }

    function getAccountGlvWithdrawalKeys(DataStore dataStore, address account, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.accountGlvWithdrawalListKey(account), start, end);
    }
}
