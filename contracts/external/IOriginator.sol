// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MultichainReaderUtils} from "./MultichainReaderUtils.sol";

interface IOriginator {
    function processLzReceive(bytes32 guid, MultichainReaderUtils.ReceivedData calldata receivedDataInput) external;
}
