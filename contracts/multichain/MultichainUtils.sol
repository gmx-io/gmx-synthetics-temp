// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

/**
 * @title MultichainUtils
 */
library MultichainUtils {
    function getVirtualAccount(address account, uint256 sourceChainId) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encode("GMX Multichain", account, sourceChainId)))));
    }
}
