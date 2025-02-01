// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title IMultichainProvider
 */
interface IMultichainProvider {
    // lzCompose is LZ specific. If defined here, interface should be named ILayerZeroProvider instead of IMultichainProvider
    // function lzCompose(address from, bytes32 guid, bytes calldata message, address executor, bytes calldata extraData) external payable;
}
