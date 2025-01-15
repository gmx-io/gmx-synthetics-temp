// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MultichainReaderUtils} from "./MultichainReaderUtils.sol";

interface IOriginator {
    function processSendReadRequests(bytes32 guid, MultichainReaderUtils.ReceivedData memory receivedDataInput, bytes memory transactionCallData) external;
    function processLzReceive(bytes32 guid, MultichainReaderUtils.ReceivedData memory receivedDataInput) external;
    function receivedData(bytes32 guid) external view returns (uint256, uint256, bool, bytes memory);
    function transactionCallData(bytes32 guid) external view returns (bytes memory);
    function latestReadNumber() external view returns (uint256);
}
