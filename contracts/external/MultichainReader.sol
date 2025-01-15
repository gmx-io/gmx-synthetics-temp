// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {MessagingParams, MessagingFee, MessagingReceipt, ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {EVMCallRequestV1, ReadCodecV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {MultichainReaderUtils} from "./MultichainReaderUtils.sol";
import {IOriginator} from "./IOriginator.sol";

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../role/RoleModule.sol";

contract MultichainReader is RoleModule {
    uint64 internal constant SENDER_VERSION = 1;
    uint64 internal constant RECEIVER_VERSION = 2;
    uint8 internal constant WORKER_ID = 1;
    uint8 internal constant OPTION_TYPE_LZREAD = 5;
    uint16 internal constant TYPE_3 = 3;

    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;
    ILayerZeroEndpointV2 public immutable endpoint;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        address _endpoint
    ) RoleModule(_roleStore) {
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
        endpoint = ILayerZeroEndpointV2(_endpoint);
        endpoint.setDelegate(msg.sender);
    }

    // TODO: add modifier for access control
    function setDelegate(address _delegate) external {
        endpoint.setDelegate(_delegate);
    }

    function sendReadRequests(
        MultichainReaderUtils.ReadRequestInputs[] calldata readRequestInputs,
        MultichainReaderUtils.ExtraOptionsInputs calldata extraOptionsInputs
    ) external payable returns (MessagingReceipt memory, bytes32, MultichainReaderUtils.ReceivedData memory) {
        address originator = msg.sender;
        bool isAuthorized = datastore.getBool(Keys.multichainAuthorizedOriginatorsKey(originator));
        if (!isAuthorized) {
            revert Errors.UnauthorizedOriginator(originator);
        }

        bytes memory cmd = _getCmd(readRequestInputs);
        MessagingReceipt memory messagingReceipt = _lzSend(
            uint32(dataStore.getUint(Keys.MULTICHAIN_READ_CHANNEL)),
            cmd,
            _extraOptions(extraOptionsInputs),
            MessagingFee(msg.value, 0),
            payable(originator)
        );

        bytes32 guid = messagingReceipt.guid;
        dataStore.setAddress(keys.multichainGuidToOriginatorKey(guid), originator);

        MultichainReaderUtils.ReceivedData memory receivedData;
        receivedData.readNumber = IOriginator(originator).latestReadNumber() + 1;
        receivedData.timestamp = block.timestamp;

        return (messagingReceipt, guid, receivedData);
    }

    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        // Ensures that only the endpoint can attempt to lzReceive() messages to this OApp.
        if (address(endpoint) != msg.sender) revert Errors.OnlyEndpoint(msg.sender);

        // Ensure that the sender matches the expected peer for the source endpoint.
        if (_getPeerOrRevert(_origin.srcEid) != _origin.sender) revert Errors.OnlyPeer(_origin.srcEid, _origin.sender);

        // Call the internal OApp implementation of lzReceive.
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    function peers(uint32 _eid) external view returns (bytes32 peer) {
        peer = datastore.getBytes32(keys.multichainPeersKey(_eid));
    }

    function quoteReadFee(
        MultichainReaderUtils.ReadRequestInputs[] calldata readRequestInputs,
        MultichainReaderUtils.ExtraOptionsInputs calldata extraOptionsInputs
    ) external view returns (MessagingFee memory fee) {
        return _quote(uint32(dataStore.getUint(Keys.MULTICHAIN_READ_CHANNEL)), _getCmd(readRequestInputs), _extraOptions(extraOptionsInputs));
    }

    function isComposeMsgSender(
        Origin calldata /*_origin*/,
        bytes calldata /*_message*/,
        address _sender
    ) external view returns (bool) {
        return _sender == address(this);
    }

    function allowInitializePath(Origin calldata origin) external view returns (bool) {
        return datastore.getBytes32(keys.multichainPeersKey(origin.srcEid));
    }

    function nextNonce(uint32 /*_srcEid*/, bytes32 /*_sender*/) external pure returns (uint64 nonce) {
        return 0;
    }

    function oAppVersion() external pure returns (uint64 senderVersion, uint64 receiverVersion) {
        return (SENDER_VERSION, RECEIVER_VERSION);
    }

    function _lzSend(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options,
        MessagingFee memory _fee,
        address _refundAddress
    ) internal returns (MessagingReceipt memory receipt) {
        // @dev Push corresponding fees to the endpoint, any excess is sent back to the _refundAddress from the endpoint.
        uint256 messageValue = _payNative(_fee.nativeFee);

        return
            // solhint-disable-next-line check-send-result
            endpoint.send{value: messageValue}(
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, false),
                _refundAddress
            );
    }

    function _lzReceive(
        Origin calldata /*_origin*/,
        bytes32 _guid,
        bytes calldata _message,
        address /*_executor*/,
        bytes calldata /*_extraData*/
    ) internal {
        address originator = dataStore.getAddress(keys.multichainGuidToOriginatorKey(guid));

        (uint256 readNumber, uint256 timestamp, bool received, bytes memory readData) = IOriginator(originator)
            .receivedData(_guid);
        MultichainReaderUtils.ReceivedData memory receivedData = MultichainReaderUtils.ReceivedData(
            readNumber,
            timestamp,
            received,
            readData
        );
        receivedData.received = true;
        receivedData.readData = _message;

        IOriginator(originator).processLzReceive(_guid, receivedData);
        bytes memory transactionCallData = IOriginator(originator).transactionCallData(_guid);
        if (transactionCallData.length != 0) {
            (bool success, ) = originator.call(transactionCallData);
            if (!success) {
                revert Errors.OriginatorCallFailed(transactionCallData);
            }
        }
    }

    function _payNative(uint256 _nativeFee) internal returns (uint256 nativeFee) {
        if (msg.value != _nativeFee) revert Errors.NotEnoughNative(msg.value);
        return _nativeFee;
    }

    function _getCmd(
        MultichainReaderUtils.ReadRequestInputs[] calldata readRequestInputs
    ) internal view returns (bytes memory) {
        uint256 readRequestCount = readRequestInputs.length;
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](readRequestCount);
        for (uint256 i; i < readRequestCount; i++) {
            uint32 chainId = readRequestInputs[i].chainId;
            readRequests[i] = EVMCallRequestV1({
                appRequestLabel: 1,
                targetEid: chainId, // Endpoint ID of the target chain
                isBlockNum: false, // Use timestamp instead of block number
                blockNumOrTimestamp: uint64(block.timestamp), // Timestamp to read the state at
                confirmations: uint16(dataStore.getUint(multichainConfirmationsKey(chainId))), // Number of confirmations to wait for finality
                to: readRequestInputs[i].target, // Address of the contract to call
                callData: readRequestInputs[i].callData // Encoded function call data
            });
        }

        return ReadCodecV1.encode(0, readRequests);
    }

    function _getPeerOrRevert(uint32 _eid) internal view returns (bytes32) {
        bytes32 peer = datastore.getBytes32(keys.multichainPeersKey(_eid));
        if (peer == bytes32(0)) revert Errors.NoPeer(_eid);
        return peer;
    }

    function _quote(
        uint32 _dstEid,
        bytes memory _message,
        bytes memory _options
    ) internal view returns (MessagingFee memory fee) {
        return
            endpoint.quote(
                MessagingParams(_dstEid, _getPeerOrRevert(_dstEid), _message, _options, false),
                address(this)
            );
    }

    function _extraOptions(
        MultichainReaderUtils.ExtraOptionsInputs calldata extraOptionsInputs
    ) internal pure returns (bytes memory) {
        bytes memory option = extraOptionsInputs.msgValue == 0
            ? abi.encodePacked(extraOptionsInputs.gasLimit, extraOptionsInputs.returnDataSize)
            : abi.encodePacked(
                extraOptionsInputs.gasLimit,
                extraOptionsInputs.returnDataSize,
                extraOptionsInputs.msgValue
            );
        return
            abi.encodePacked(
                abi.encodePacked(TYPE_3),
                WORKER_ID,
                uint16(option.length) + 1, // +1 for optionType
                OPTION_TYPE_LZREAD,
                option
            );
    }
}
