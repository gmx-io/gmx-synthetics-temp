// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

library Shift {
    struct Props {
        Addresses addresses;
        Numbers numbers;
        bytes32[] _dataList;
    }

    struct Addresses {
        address account;
        address receiver;
        address callbackContract;
        address uiFeeReceiver;
        address fromMarket;
        address toMarket;
    }

    struct Numbers {
        uint256 marketTokenAmount;
        uint256 minMarketTokens;
        uint256 updatedAtTime;
        uint256 executionFee;
        uint256 callbackGasLimit;
    }

    function account(Props memory props) internal pure returns (address) {
        return props.addresses.account;
    }

    function setAccount(Props memory props, address value) internal pure {
        props.addresses.account = value;
    }

    function receiver(Props memory props) internal pure returns (address) {
        return props.addresses.receiver;
    }

    function setReceiver(Props memory props, address value) internal pure {
        props.addresses.receiver = value;
    }

    function callbackContract(Props memory props) internal pure returns (address) {
        return props.addresses.callbackContract;
    }

    function setCallbackContract(Props memory props, address value) internal pure {
        props.addresses.callbackContract = value;
    }

    function uiFeeReceiver(Props memory props) internal pure returns (address) {
        return props.addresses.uiFeeReceiver;
    }

    function setUiFeeReceiver(Props memory props, address value) internal pure {
        props.addresses.uiFeeReceiver = value;
    }

    function fromMarket(Props memory props) internal pure returns (address) {
        return props.addresses.fromMarket;
    }

    function setFromMarket(Props memory props, address value) internal pure {
        props.addresses.fromMarket = value;
    }

    function toMarket(Props memory props) internal pure returns (address) {
        return props.addresses.toMarket;
    }

    function setToMarket(Props memory props, address value) internal pure {
        props.addresses.toMarket = value;
    }

    function marketTokenAmount(Props memory props) internal pure returns (uint256) {
        return props.numbers.marketTokenAmount;
    }

    function setMarketTokenAmount(Props memory props, uint256 value) internal pure {
        props.numbers.marketTokenAmount = value;
    }

    function minMarketTokens(Props memory props) internal pure returns (uint256) {
        return props.numbers.minMarketTokens;
    }

    function setMinMarketTokens(Props memory props, uint256 value) internal pure {
        props.numbers.minMarketTokens = value;
    }

    function updatedAtTime(Props memory props) internal pure returns (uint256) {
        return props.numbers.updatedAtTime;
    }

    function setUpdatedAtTime(Props memory props, uint256 value) internal pure {
        props.numbers.updatedAtTime = value;
    }

    function executionFee(Props memory props) internal pure returns (uint256) {
        return props.numbers.executionFee;
    }

    function setExecutionFee(Props memory props, uint256 value) internal pure {
        props.numbers.executionFee = value;
    }

    function callbackGasLimit(Props memory props) internal pure returns (uint256) {
        return props.numbers.callbackGasLimit;
    }

    function setCallbackGasLimit(Props memory props, uint256 value) internal pure {
        props.numbers.callbackGasLimit = value;
    }

    function dataList(Props memory props) internal pure returns (bytes32[] memory) {
        return props._dataList;
    }

    function setDataList(Props memory props, bytes32[] memory value) internal pure {
        props._dataList = value;
    }
}
