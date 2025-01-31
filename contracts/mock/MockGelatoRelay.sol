// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../data/DataStore.sol";
import "../event/EventEmitter.sol";
import "../exchange/IOrderHandler.sol";
import "../order/OrderVault.sol";
import "../router/Router.sol";
import "../router/relay/GelatoRelayRouter.sol";

contract MockGelatoRelayRouter is GelatoRelayRouter {
    struct Nested {
        uint256 foo;
        bool bar;
    }

    constructor(
        Router _router,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        IOrderHandler _orderHandler,
        OrderVault _orderVault
    ) GelatoRelayRouter(_router, _dataStore, _eventEmitter, _oracle, _orderHandler, _orderVault) {}

    function testCancelOrderSignature(
        RelayParams calldata relayParams,
        bytes32 key,
        address account,
        uint256 chainId
    ) external view {
        bytes32 structHash = _getCancelOrderStructHash(relayParams, key);
        _handleSignature(structHash, relayParams.signature, account, chainId);
    }

    function testSimpleSignature(address account, bytes calldata signature, uint256 chainId) external view {
        bytes32 structHash = keccak256(abi.encode(keccak256(bytes("PrimaryStruct(address account)")), account));
        _handleSignature(structHash, signature, account, chainId);
    }

    function testNestedSignature(
        Nested memory nested,
        address account,
        bytes calldata signature,
        uint256 chainId
    ) external view {
        bytes32 nestedStructHash = keccak256(
            abi.encode(keccak256(bytes("Nested(uint256 foo,bool bar)")), nested.foo, nested.bar)
        );
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(bytes("PrimaryStruct(address account,Nested nested)Nested(uint256 foo,bool bar)")),
                account,
                nestedStructHash
            )
        );
        _handleSignature(structHash, signature, account, chainId);
    }

    function testArraySignature(
        address[] memory array,
        address account,
        bytes calldata signature,
        uint256 chainId
    ) external view {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(bytes("PrimaryStruct(address account,address[] array)")),
                account,
                keccak256(abi.encodePacked(array))
            )
        );
        _handleSignature(structHash, signature, account, chainId);
    }

    function _handleSignature(
        bytes32 structHash,
        bytes calldata signature,
        address account,
        uint256 chainId
    ) internal view {
        bytes32 domainSeparator = _getDomainSeparator(chainId);
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);

        _validateSignature(digest, signature, account, "call");
    }
}
