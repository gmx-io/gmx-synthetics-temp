// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import { MultichainProviderUtils } from "./MultichainProviderUtils.sol";

contract MultichainProviderSignature is EIP712 {
    using ECDSA for bytes32;

    string private constant SIGNING_DOMAIN = "MultichainProviderSignatureDomain";
    string private constant SIGNATURE_VERSION = "1";

    // Define the EIP-712 struct type:
    // Message(address token,uint256 amount,address account,uint256 sourceChainId,uint32 srcEid)
    bytes32 private constant _MESSAGE_TYPEHASH =
        keccak256("Message(address token,uint256 amount,address account,uint256 sourceChainId,uint32 srcEid)");

    constructor() EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION) {}

    /**
     * Check the signature for a given message
     * @param message The ABI encoded parameters (token, amount, account, sourceChainId, srcEid).
     * @param signature The EIP-712 signature.
     */
    function isSigner(bytes calldata message, bytes calldata signature) external view returns (bool) {
        // Decode the message
        (address token, uint256 amount, address account, uint256 sourceChainId, uint32 srcEid) = MultichainProviderUtils
            .decodeWithdrawal(message);

        // Build the struct hash
        bytes32 structHash = keccak256(abi.encode(_MESSAGE_TYPEHASH, token, amount, account, sourceChainId, srcEid));

        // Get the typed data hash for EIP-712
        bytes32 hash = _hashTypedDataV4(structHash);

        // Recover the signer from the signature
        address signer = ECDSA.recover(hash, signature);

        return signer == account;
    }
}
