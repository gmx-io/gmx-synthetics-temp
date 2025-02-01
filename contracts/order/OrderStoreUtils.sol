// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/Keys.sol";
import "../data/DataStore.sol";

import "./Order.sol";

/**
 * @title OrderStoreUtils
 * @dev Library for order storage functions
 */
library OrderStoreUtils {
    using Order for Order.Props;

    bytes32 public constant ACCOUNT = keccak256(abi.encode("ACCOUNT"));
    bytes32 public constant RECEIVER = keccak256(abi.encode("RECEIVER"));
    bytes32 public constant CANCELLATION_RECEIVER = keccak256(abi.encode("CANCELLATION_RECEIVER"));
    bytes32 public constant CALLBACK_CONTRACT = keccak256(abi.encode("CALLBACK_CONTRACT"));
    bytes32 public constant UI_FEE_RECEIVER = keccak256(abi.encode("UI_FEE_RECEIVER"));
    bytes32 public constant MARKET = keccak256(abi.encode("MARKET"));
    bytes32 public constant INITIAL_COLLATERAL_TOKEN = keccak256(abi.encode("INITIAL_COLLATERAL_TOKEN"));
    bytes32 public constant SWAP_PATH = keccak256(abi.encode("SWAP_PATH"));

    bytes32 public constant ORDER_TYPE = keccak256(abi.encode("ORDER_TYPE"));
    bytes32 public constant DECREASE_POSITION_SWAP_TYPE = keccak256(abi.encode("DECREASE_POSITION_SWAP_TYPE"));
    bytes32 public constant SIZE_DELTA_USD = keccak256(abi.encode("SIZE_DELTA_USD"));
    bytes32 public constant INITIAL_COLLATERAL_DELTA_AMOUNT = keccak256(abi.encode("INITIAL_COLLATERAL_DELTA_AMOUNT"));
    bytes32 public constant TRIGGER_PRICE = keccak256(abi.encode("TRIGGER_PRICE"));
    bytes32 public constant ACCEPTABLE_PRICE = keccak256(abi.encode("ACCEPTABLE_PRICE"));
    bytes32 public constant EXECUTION_FEE = keccak256(abi.encode("EXECUTION_FEE"));
    bytes32 public constant CALLBACK_GAS_LIMIT = keccak256(abi.encode("CALLBACK_GAS_LIMIT"));
    bytes32 public constant MIN_OUTPUT_AMOUNT = keccak256(abi.encode("MIN_OUTPUT_AMOUNT"));
    bytes32 public constant VALID_FROM_TIME = keccak256(abi.encode("VALID_FROM_TIME"));
    bytes32 public constant UPDATED_AT_TIME = keccak256(abi.encode("UPDATED_AT_TIME"));

    bytes32 public constant IS_LONG = keccak256(abi.encode("IS_LONG"));
    bytes32 public constant SHOULD_UNWRAP_NATIVE_TOKEN = keccak256(abi.encode("SHOULD_UNWRAP_NATIVE_TOKEN"));
    bytes32 public constant IS_FROZEN = keccak256(abi.encode("IS_FROZEN"));
    bytes32 public constant AUTO_CANCEL = keccak256(abi.encode("AUTO_CANCEL"));

    bytes32 public constant DATA_LIST = keccak256(abi.encode("DATA_LIST"));

    function get(DataStore dataStore, bytes32 key) external view returns (Order.Props memory) {
        Order.Props memory order;
        if (!dataStore.containsBytes32(Keys.ORDER_LIST, key)) {
            return order;
        }

        order.setAccount(dataStore.getAddress(
            keccak256(abi.encode(key, ACCOUNT))
        ));

        order.setReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, RECEIVER))
        ));

        order.setCancellationReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, CANCELLATION_RECEIVER))
        ));

        order.setCallbackContract(dataStore.getAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT))
        ));

        order.setUiFeeReceiver(dataStore.getAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER))
        ));

        order.setMarket(dataStore.getAddress(
            keccak256(abi.encode(key, MARKET))
        ));

        order.setInitialCollateralToken(dataStore.getAddress(
            keccak256(abi.encode(key, INITIAL_COLLATERAL_TOKEN))
        ));

        order.setSwapPath(dataStore.getAddressArray(
            keccak256(abi.encode(key, SWAP_PATH))
        ));

        order.setOrderType(Order.OrderType(dataStore.getUint(
            keccak256(abi.encode(key, ORDER_TYPE))
        )));

        order.setDecreasePositionSwapType(Order.DecreasePositionSwapType(dataStore.getUint(
            keccak256(abi.encode(key, DECREASE_POSITION_SWAP_TYPE))
        )));

        order.setSizeDeltaUsd(dataStore.getUint(
            keccak256(abi.encode(key, SIZE_DELTA_USD))
        ));

        order.setInitialCollateralDeltaAmount(dataStore.getUint(
            keccak256(abi.encode(key, INITIAL_COLLATERAL_DELTA_AMOUNT))
        ));

        order.setTriggerPrice(dataStore.getUint(
            keccak256(abi.encode(key, TRIGGER_PRICE))
        ));

        order.setAcceptablePrice(dataStore.getUint(
            keccak256(abi.encode(key, ACCEPTABLE_PRICE))
        ));

        order.setExecutionFee(dataStore.getUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        ));

        order.setCallbackGasLimit(dataStore.getUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        ));

        order.setMinOutputAmount(dataStore.getUint(
            keccak256(abi.encode(key, MIN_OUTPUT_AMOUNT))
        ));

        order.setValidFromTime(dataStore.getUint(
            keccak256(abi.encode(key, VALID_FROM_TIME))
        ));

        order.setUpdatedAtTime(dataStore.getUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        ));

        order.setIsLong(dataStore.getBool(
            keccak256(abi.encode(key, IS_LONG))
        ));

        order.setShouldUnwrapNativeToken(dataStore.getBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        ));

        order.setIsFrozen(dataStore.getBool(
            keccak256(abi.encode(key, IS_FROZEN))
        ));

        order.setAutoCancel(dataStore.getBool(
            keccak256(abi.encode(key, AUTO_CANCEL))
        ));

        order.setDataList(dataStore.getBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        ));

        return order;
    }

    function set(DataStore dataStore, bytes32 key, Order.Props memory order) external {
        dataStore.addBytes32(
            Keys.ORDER_LIST,
            key
        );

        dataStore.addBytes32(
            Keys.accountOrderListKey(order.account()),
            key
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, ACCOUNT)),
            order.account()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, RECEIVER)),
            order.receiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, CANCELLATION_RECEIVER)),
            order.cancellationReceiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, CALLBACK_CONTRACT)),
            order.callbackContract()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, UI_FEE_RECEIVER)),
            order.uiFeeReceiver()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, MARKET)),
            order.market()
        );

        dataStore.setAddress(
            keccak256(abi.encode(key, INITIAL_COLLATERAL_TOKEN)),
            order.initialCollateralToken()
        );

        dataStore.setAddressArray(
            keccak256(abi.encode(key, SWAP_PATH)),
            order.swapPath()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, ORDER_TYPE)),
            uint256(order.orderType())
        );

        dataStore.setUint(
            keccak256(abi.encode(key, DECREASE_POSITION_SWAP_TYPE)),
            uint256(order.decreasePositionSwapType())
        );

        dataStore.setUint(
            keccak256(abi.encode(key, SIZE_DELTA_USD)),
            order.sizeDeltaUsd()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, INITIAL_COLLATERAL_DELTA_AMOUNT)),
            order.initialCollateralDeltaAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, TRIGGER_PRICE)),
            order.triggerPrice()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, ACCEPTABLE_PRICE)),
            order.acceptablePrice()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, EXECUTION_FEE)),
            order.executionFee()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT)),
            order.callbackGasLimit()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, MIN_OUTPUT_AMOUNT)),
            order.minOutputAmount()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, VALID_FROM_TIME)),
            order.validFromTime()
        );

        dataStore.setUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME)),
            order.updatedAtTime()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, IS_LONG)),
            order.isLong()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN)),
            order.shouldUnwrapNativeToken()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, IS_FROZEN)),
            order.isFrozen()
        );

        dataStore.setBool(
            keccak256(abi.encode(key, AUTO_CANCEL)),
            order.autoCancel()
        );

        dataStore.setBytes32Array(
            keccak256(abi.encode(key, DATA_LIST)),
            order.dataList()
        );
    }

    function remove(DataStore dataStore, bytes32 key, address account) external {
        if (!dataStore.containsBytes32(Keys.ORDER_LIST, key)) {
            revert Errors.OrderNotFound(key);
        }

        dataStore.removeBytes32(
            Keys.ORDER_LIST,
            key
        );

        dataStore.removeBytes32(
            Keys.accountOrderListKey(account),
            key
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, ACCOUNT))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, RECEIVER))
        );

        dataStore.removeAddress(
            keccak256(abi.encode(key, CANCELLATION_RECEIVER))
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
            keccak256(abi.encode(key, INITIAL_COLLATERAL_TOKEN))
        );

        dataStore.removeAddressArray(
            keccak256(abi.encode(key, SWAP_PATH))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, ORDER_TYPE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, DECREASE_POSITION_SWAP_TYPE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, SIZE_DELTA_USD))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, INITIAL_COLLATERAL_DELTA_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, TRIGGER_PRICE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, ACCEPTABLE_PRICE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, EXECUTION_FEE))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, CALLBACK_GAS_LIMIT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, MIN_OUTPUT_AMOUNT))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, VALID_FROM_TIME))
        );

        dataStore.removeUint(
            keccak256(abi.encode(key, UPDATED_AT_TIME))
        );

        dataStore.removeBool(
            keccak256(abi.encode(key, IS_LONG))
        );

        dataStore.removeBool(
            keccak256(abi.encode(key, SHOULD_UNWRAP_NATIVE_TOKEN))
        );

        dataStore.removeBool(
            keccak256(abi.encode(key, IS_FROZEN))
        );

        dataStore.removeBool(
            keccak256(abi.encode(key, AUTO_CANCEL))
        );

        dataStore.removeBytes32Array(
            keccak256(abi.encode(key, DATA_LIST))
        );
    }

    function getOrderCount(DataStore dataStore) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.ORDER_LIST);
    }

    function getOrderKeys(DataStore dataStore, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.ORDER_LIST, start, end);
    }

    function getAccountOrderCount(DataStore dataStore, address account) internal view returns (uint256) {
        return dataStore.getBytes32Count(Keys.accountOrderListKey(account));
    }

    function getAccountOrderKeys(DataStore dataStore, address account, uint256 start, uint256 end) internal view returns (bytes32[] memory) {
        return dataStore.getBytes32ValuesAt(Keys.accountOrderListKey(account), start, end);
    }
}
