// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/Keys.sol";
import "../data/DataStore.sol";

import "./Deposit.sol";

/**
 * @title DepositStoreUtils
 * @dev Library for deposit storage functions
 */
library DepositStoreUtils {
    using Deposit for Deposit.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant RECEIVER = keccak256(abi.encode("RECEIVER"));
    bytes32 public constant CALLBACK_CONTRACT = keccak256(abi.encode("CALLBACK_CONTRACT"));
    bytes32 public constant UI_FEE_RECEIVER = keccak256(abi.encode("UI_FEE_RECEIVER"));
    bytes32 public constant MARKET = keccak256(abi.encode("MARKET"));
    bytes32 public constant INITIAL_LONG_TOKEN = keccak256(abi.encode("INITIAL_LONG_TOKEN"));
    bytes32 public constant INITIAL_SHORT_TOKEN = keccak256(abi.encode("INITIAL_SHORT_TOKEN"));
    bytes32 public constant LONG_TOKEN_SWAP_PATH = keccak256(abi.encode("LONG_TOKEN_SWAP_PATH"));
    bytes32 public constant SHORT_TOKEN_SWAP_PATH = keccak256(abi.encode("SHORT_TOKEN_SWAP_PATH"));

    bytes32 public constant INITIAL_LONG_TOKEN_AMOUNT = keccak256(abi.encode("INITIAL_LONG_TOKEN_AMOUNT"));
    bytes32 public constant INITIAL_SHORT_TOKEN_AMOUNT = keccak256(abi.encode("INITIAL_SHORT_TOKEN_AMOUNT"));
    bytes32 public constant MIN_MARKET_TOKENS = keccak256(abi.encode("MIN_MARKET_TOKENS"));
    bytes32 public constant UPDATED_AT_TIME = keccak256(abi.encode("UPDATED_AT_TIME"));
    bytes32 public constant EXECUTION_FEE = keccak256(abi.encode("EXECUTION_FEE"));
    bytes32 public constant CALLBACK_GAS_LIMIT = keccak256(abi.encode("CALLBACK_GAS_LIMIT"));
    bytes32 public constant CHAIN_ID = keccak256(abi.encode("CHAIN_ID"));

    bytes32 public constant SHOULD_UNWRAP_NATIVE_TOKEN = keccak256(abi.encode("SHOULD_UNWRAP_NATIVE_TOKEN"));

    bytes32 public constant DATA_LIST = keccak256(abi.encode("DATA_LIST"));

    function get(DataStore dataStore, bytes32 key) external view returns (Deposit.Props memory) {
        Deposit.Props memory deposit;
        if (!dataStore.containsBytes32(Keys.DEPOSIT_LIST, key)) {
            return deposit;
        }

        deposit.setAccount(dataStore.getAddress(
            keccak256(abi.encode(key, ACCOUNT))
        ));

        deposit.setReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, RECEIVER))
        ));

        deposit.setCallbackContract(dataStore.getAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT))
        ));

        deposit.setUiFeeReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER))
        ));

        deposit.setMarket(dataStore.getAddress(
            keccak256(abi.encode(key, MARKET))
        ));

        deposit.setInitialLongToken(dataStore.getAddress(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN))
        ));

        deposit.setInitialShortToken(dataStore.getAddress(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN))
        ));

        deposit.setLongTokenSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH))
        ));

        deposit.setShortTokenSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH))
        ));

        deposit.setInitialLongTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN_AMOUNT))
        ));

        deposit.setInitialShortTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN_AMOUNT))
        ));

        deposit.setMinMarketTokens(dataStore.getUint(
            keccak256(abi.encode(key, MIN_MARKET_TOKENS))
        ));

        deposit.setUpdatedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        ));

        deposit.setExecutionFee(dataStore.getUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        ));

        deposit.setCallbackGasLimit(dataStore.getUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        ));

        deposit.setChainId(dataStore.getUint(
            keccak256(abi.encode(key, CHAIN_ID))
        ));

        deposit.setShouldUnwrapNativeToken(dataStore.getBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        ));

        deposit.setDataList(dataStore.getBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        ));

        return deposit;
    }

    function set(DataStore dataStore, bytes32 key, Deposit.Props memory deposit) external {
        dataStore.addBytes32(
            Keys.DEPOSIT_LIST,
            key
        );

        dataStore.addBytes32(
            Keys.accountDepositListKey(deposit.account()),
            key
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, ACCOUNT)),
            deposit.account()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, RECEIVER)),
            deposit.receiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT)),
            deposit.callbackContract()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER)),
            deposit.uiFeeReceiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, MARKET)),
            deposit.market()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN)),
            deposit.initialLongToken()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN)),
            deposit.initialShortToken()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH)),
            deposit.longTokenSwapPath()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH)),
            deposit.shortTokenSwapPath()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN_AMOUNT)),
            deposit.initialLongTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN_AMOUNT)),
            deposit.initialShortTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MIN_MARKET_TOKENS)),
            deposit.minMarketTokens()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME)),
            deposit.updatedAtTime()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, EXECUTION_FEE)),
            deposit.executionFee()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT)),
            deposit.callbackGasLimit()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, CHAIN_ID)),
            deposit.chainId()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN)),
            deposit.shouldUnwrapNativeToken()
        );

        dataStore.setBytes32Array(
            keccak256(abi.encode(key, DATA_LIST)),
            deposit.dataList()
        );
    }

    function remove(DataStore dataStore, bytes32 key, address account) external {
        if (!dataStore.containsBytes32(Keys.DEPOSIT_LIST, key)) {
            revert Errors.DepositNotFound(key);
        }

        dataStore.removeBytes32(
            Keys.DEPOSIT_LIST,
            key
        );

        dataStore.removeBytes32(
            Keys.accountDepositListKey(account),
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
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN))
        );

        dataStore.removeAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH))
        );

        dataStore.removeAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN_AMOUNT))
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

        dataStore.removeUint(
            keccak256(abi.encode(key, CHAIN_ID))
        );

        dataStore.removeBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        );

        dataStore.removeBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        );
    }

    function getDepositCount(DataStore dataStore) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.DEPOSIT_LIST);
    }

    function getDepositKeys(DataStore dataStore, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.DEPOSIT_LIST, start, end);
    }

    function getAccountDepositCount(DataStore dataStore, address account) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.accountDepositListKey(account));
    }

    function getAccountDepositKeys(DataStore dataStore, address account, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.accountDepositListKey(account), start, end);
    }
}
