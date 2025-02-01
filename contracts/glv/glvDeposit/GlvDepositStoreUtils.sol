// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../../data/Keys.sol";
import "../../data/DataStore.sol";

import "./GlvDeposit.sol";

/**
 * @title GlvDepositStoreUtils
 * @dev Library for deposit storage functions
 */
library GlvDepositStoreUtils {
    using GlvDeposit for GlvDeposit.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant RECEIVER = keccak256(abi.encode("RECEIVER"));
    bytes32 public constant CALLBACK_CONTRACT = keccak256(abi.encode("CALLBACK_CONTRACT"));
    bytes32 public constant UI_FEE_RECEIVER = keccak256(abi.encode("UI_FEE_RECEIVER"));
    bytes32 public constant GLV = keccak256(abi.encode("GLV"));
    bytes32 public constant MARKET = keccak256(abi.encode("MARKET"));
    bytes32 public constant INITIAL_LONG_TOKEN = keccak256(abi.encode("INITIAL_LONG_TOKEN"));
    bytes32 public constant INITIAL_SHORT_TOKEN = keccak256(abi.encode("INITIAL_SHORT_TOKEN"));
    bytes32 public constant LONG_TOKEN_SWAP_PATH = keccak256(abi.encode("LONG_TOKEN_SWAP_PATH"));
    bytes32 public constant SHORT_TOKEN_SWAP_PATH = keccak256(abi.encode("SHORT_TOKEN_SWAP_PATH"));

    bytes32 public constant MARKET_TOKEN_AMOUNT = keccak256(abi.encode("MARKET_TOKEN_AMOUNT"));
    bytes32 public constant INITIAL_LONG_TOKEN_AMOUNT = keccak256(abi.encode("INITIAL_LONG_TOKEN_AMOUNT"));
    bytes32 public constant INITIAL_SHORT_TOKEN_AMOUNT = keccak256(abi.encode("INITIAL_SHORT_TOKEN_AMOUNT"));
    bytes32 public constant MIN_GLV_TOKENS = keccak256(abi.encode("MIN_GLV_TOKENS"));
    bytes32 public constant UPDATED_AT_TIME = keccak256(abi.encode("UPDATED_AT_TIME"));
    bytes32 public constant EXECUTION_FEE = keccak256(abi.encode("EXECUTION_FEE"));
    bytes32 public constant CALLBACK_GAS_LIMIT = keccak256(abi.encode("CALLBACK_GAS_LIMIT"));

    bytes32 public constant SHOULD_UNWRAP_NATIVE_TOKEN = keccak256(abi.encode("SHOULD_UNWRAP_NATIVE_TOKEN"));
    bytes32 public constant IS_MARKET_TOKEN_DEPOSIT = keccak256(abi.encode("IS_MARKET_TOKEN_DEPOSIT"));

    bytes32 public constant DATA_LIST = keccak256(abi.encode("DATA_LIST"));

    function get(DataStore dataStore, bytes32 key) external view returns (GlvDeposit.Props memory) {
        GlvDeposit.Props memory glvDeposit;
        if (!dataStore.containsBytes32(Keys.GLV_DEPOSIT_LIST, key)) {
            return glvDeposit;
        }

        glvDeposit.setAccount(dataStore.getAddress(
            keccak256(abi.encode(key, ACCOUNT))
        ));

        glvDeposit.setReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, RECEIVER))
        ));

        glvDeposit.setCallbackContract(dataStore.getAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT))
        ));

        glvDeposit.setUiFeeReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER))
        ));

        glvDeposit.setGlv(dataStore.getAddress(
            keccak256(abi.encode(key, GLV))
        ));

        glvDeposit.setMarket(dataStore.getAddress(
            keccak256(abi.encode(key, MARKET))
        ));

        glvDeposit.setInitialLongToken(dataStore.getAddress(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN))
        ));

        glvDeposit.setInitialShortToken(dataStore.getAddress(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN))
        ));

        glvDeposit.setLongTokenSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH))
        ));

        glvDeposit.setShortTokenSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH))
        ));

        glvDeposit.setMarketTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, MARKET_TOKEN_AMOUNT))
        ));

        glvDeposit.setInitialLongTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN_AMOUNT))
        ));

        glvDeposit.setInitialShortTokenAmount(dataStore.getUint(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN_AMOUNT))
        ));

        glvDeposit.setMinGlvTokens(dataStore.getUint(
            keccak256(abi.encode(key, MIN_GLV_TOKENS))
        ));

        glvDeposit.setUpdatedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        ));

        glvDeposit.setExecutionFee(dataStore.getUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        ));

        glvDeposit.setCallbackGasLimit(dataStore.getUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        ));

        glvDeposit.setShouldUnwrapNativeToken(dataStore.getBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        ));

        glvDeposit.setIsMarketTokenDeposit(dataStore.getBool(
            keccak256(abi.encode(key, IS_MARKET_TOKEN_DEPOSIT))
        ));

        glvDeposit.setDataList(dataStore.getBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        ));

        return glvDeposit;
    }

    function set(DataStore dataStore, bytes32 key, GlvDeposit.Props memory glvDeposit) external {
        dataStore.addBytes32(
            Keys.GLV_DEPOSIT_LIST,
            key
        );

        dataStore.addBytes32(
            Keys.accountGlvDepositListKey(glvDeposit.account()),
            key
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, ACCOUNT)),
            glvDeposit.account()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, RECEIVER)),
            glvDeposit.receiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT)),
            glvDeposit.callbackContract()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER)),
            glvDeposit.uiFeeReceiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, GLV)),
            glvDeposit.glv()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, MARKET)),
            glvDeposit.market()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN)),
            glvDeposit.initialLongToken()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN)),
            glvDeposit.initialShortToken()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, LONG_TOKEN_SWAP_PATH)),
            glvDeposit.longTokenSwapPath()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, SHORT_TOKEN_SWAP_PATH)),
            glvDeposit.shortTokenSwapPath()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MARKET_TOKEN_AMOUNT)),
            glvDeposit.marketTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN_AMOUNT)),
            glvDeposit.initialLongTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN_AMOUNT)),
            glvDeposit.initialShortTokenAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MIN_GLV_TOKENS)),
            glvDeposit.minGlvTokens()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME)),
            glvDeposit.updatedAtTime()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, EXECUTION_FEE)),
            glvDeposit.executionFee()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT)),
            glvDeposit.callbackGasLimit()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN)),
            glvDeposit.shouldUnwrapNativeToken()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, IS_MARKET_TOKEN_DEPOSIT)),
            glvDeposit.isMarketTokenDeposit()
        );

        dataStore.setBytes32Array(
            keccak256(abi.encode(key, DATA_LIST)),
            glvDeposit.dataList()
        );
    }

    function remove(DataStore dataStore, bytes32 key, address account) external {
        if (!dataStore.containsBytes32(Keys.GLV_DEPOSIT_LIST, key)) {
            revert Errors.GlvDepositNotFound(key);
        }

        dataStore.removeBytes32(
            Keys.GLV_DEPOSIT_LIST,
            key
        );

        dataStore.removeBytes32(
            Keys.accountGlvDepositListKey(account),
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
            keccak256(abi.encode(key, GLV))
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
            keccak256(abi.encode(key, MARKET_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, INITIAL_LONG_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, INITIAL_SHORT_TOKEN_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, MIN_GLV_TOKENS))
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

        dataStore.removeBool(
            keccak256(abi.encode(key, IS_MARKET_TOKEN_DEPOSIT))
        );

        dataStore.removeBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        );
    }

    function getGlvDepositCount(DataStore dataStore) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.GLV_DEPOSIT_LIST);
    }

    function getGlvDepositKeys(DataStore dataStore, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.GLV_DEPOSIT_LIST, start, end);
    }

    function getAccountGlvDepositCount(DataStore dataStore, address account) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.accountGlvDepositListKey(account));
    }

    function getAccountGlvDepositKeys(DataStore dataStore, address account, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.accountGlvDepositListKey(account), start, end);
    }
}
