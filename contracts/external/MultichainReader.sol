// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {AddressCast} from "@layerzerolabs/lz-evm-protocol-v2/contracts/libs/AddressCast.sol";
import {MessagingParams, MessagingFee, MessagingReceipt, ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {Origin} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {EVMCallRequestV1, EVMCallComputeV1, ReadCodecV1} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/ReadCodecV1.sol";
import {MultichainReaderUtils} from "./MultichainReaderUtils.sol";
import {IOriginator} from "./IOriginator.sol";

import "../data/DataStore.sol";
import "../data/Keys.sol";
import "../role/RoleModule.sol";
import "../event/EventEmitter.sol";

contract MultichainReader is RoleModule {
    using EventUtils for EventUtils.AddressItems;
    using EventUtils for EventUtils.Bytes32Items;
    using EventUtils for EventUtils.BytesItems;

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
    }

    function setDelegate(address _delegate) external onlyTimelockMultisig {
        endpoint.setDelegate(_delegate);
    }

    function sendReadRequests(
        MultichainReaderUtils.ReadRequestInputs[] calldata readRequestInputs,
        MultichainReaderUtils.ExtraOptionsInputs calldata extraOptionsInputs
    ) external payable onlyController returns (MessagingReceipt memory) {
        address originator = msg.sender;
        bool isAuthorized = dataStore.getBool(Keys.multichainAuthorizedOriginatorsKey(originator));
        if (!isAuthorized) {
            revert Errors.Unauthorized(originator, "Only Originator");
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
        dataStore.setAddress(Keys.multichainGuidToOriginatorKey(guid), originator);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "originator", originator);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "guid", guid);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "cmd", cmd);

        eventEmitter.emitEventLog1("sendReadRequests", AddressCast.toBytes32(originator), eventData);

        return (messagingReceipt);
    }

    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) external payable {
        // Ensures that only the endpoint can attempt to lzReceive() messages to this OApp.
        if (address(endpoint) != msg.sender) revert Errors.Unauthorized(msg.sender, "Only Endpoint");

        // Ensure that the sender matches the expected peer for the source endpoint.
        if (_getPeerOrRevert(_origin.srcEid) != _origin.sender)
            revert Errors.Unauthorized(AddressCast.toAddress(_origin.sender), "Only Peer");

        // Call the internal OApp implementation of lzReceive.
        _lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    function peers(uint32 _eid) external view returns (bytes32 peer) {
        peer = dataStore.getBytes32(Keys.multichainPeersKey(_eid));
    }

    function quoteReadFee(
        MultichainReaderUtils.ReadRequestInputs[] calldata readRequestInputs,
        MultichainReaderUtils.ExtraOptionsInputs calldata extraOptionsInputs
    ) external view returns (MessagingFee memory fee) {
        return
            _quote(
                uint32(dataStore.getUint(Keys.MULTICHAIN_READ_CHANNEL)),
                _getCmd(readRequestInputs),
                _extraOptions(extraOptionsInputs)
            );
    }

    function isComposeMsgSender(
        Origin calldata /*_origin*/,
        bytes calldata /*_message*/,
        address _sender
    ) external view returns (bool) {
        return _sender == address(this);
    }

    function allowInitializePath(Origin calldata origin) external view returns (bool) {
        return dataStore.getBytes32(Keys.multichainPeersKey(origin.srcEid)) == origin.sender;
    }

    function lzReduce(bytes calldata _cmd, bytes[] calldata _responses) external pure returns (bytes memory) {
        bytes memory responses;
        for (uint256 i = 0; i < _responses.length; i++) {
            responses = bytes.concat(responses, _responses[i]);
        }

        (, , EVMCallComputeV1 memory computeRequest) = ReadCodecV1.decode(_cmd);
        return bytes.concat(abi.encodePacked(computeRequest.blockNumOrTimestamp), responses);
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
        uint256 timestamp = uint64(bytes8(_message[:8]));
        bytes memory message = _message[8:_message.length];

        address originator = dataStore.getAddress(Keys.multichainGuidToOriginatorKey(_guid));
        MultichainReaderUtils.ReceivedData memory receivedData = MultichainReaderUtils.ReceivedData(timestamp, message);
        IOriginator(originator).processLzReceive(_guid, receivedData);

        EventUtils.EventLogData memory eventData;

        eventData.addressItems.initItems(1);
        eventData.addressItems.setItem(0, "originator", originator);

        eventData.bytes32Items.initItems(1);
        eventData.bytes32Items.setItem(0, "guid", _guid);

        eventData.bytesItems.initItems(1);
        eventData.bytesItems.setItem(0, "message", _message);

        eventEmitter.emitEventLog1("lzReceive", AddressCast.toBytes32(originator), eventData);
    }

    function _payNative(uint256 _nativeFee) internal returns (uint256 nativeFee) {
        if (msg.value != _nativeFee) revert Errors.InsufficientMultichainNativeFee(msg.value);
        return _nativeFee;
    }

    function _getCmd(
        MultichainReaderUtils.ReadRequestInputs[] calldata readRequestInputs
    ) internal view returns (bytes memory) {
        uint64 timestamp = uint64(block.timestamp);
        uint256 readRequestCount = readRequestInputs.length;
        EVMCallRequestV1[] memory readRequests = new EVMCallRequestV1[](readRequestCount);
        for (uint256 i; i < readRequestCount; i++) {
            uint32 chainId = readRequestInputs[i].chainId;
            readRequests[i] = EVMCallRequestV1({
                appRequestLabel: uint16(i + 1), // Application-specific label for tracking
                targetEid: chainId, // Endpoint ID of the target chain
                isBlockNum: false, // Use timestamp instead of block number
                blockNumOrTimestamp: timestamp, // Timestamp to read the state at
                confirmations: uint16(dataStore.getUint(Keys.multichainConfirmationsKey(chainId))), // Number of confirmations to wait for finality
                to: readRequestInputs[i].target, // Address of the contract to call
                callData: readRequestInputs[i].callData // Encoded function call data
            });
        }

        uint32 currentChainId = ILayerZeroEndpointV2(endpoint).eid();
        EVMCallComputeV1 memory computeRequest = EVMCallComputeV1({
            computeSetting: 1, // Use lzReduce()
            targetEid: currentChainId, // Endpoint ID of the current chain
            isBlockNum: false, // Use timestamp instead of block number
            blockNumOrTimestamp: timestamp, // Timestamp to execute the compute at
            confirmations: uint16(dataStore.getUint(Keys.multichainConfirmationsKey(currentChainId))), // Number of confirmations to wait for finality
            to: address(this) // Address of this contract to lzReduce
        });

        return ReadCodecV1.encode(0, readRequests, computeRequest);
    }

    function _getPeerOrRevert(uint32 _eid) internal view returns (bytes32) {
        bytes32 peer = dataStore.getBytes32(Keys.multichainPeersKey(_eid));
        if (peer == bytes32(0)) revert Errors.EmptyPeer(_eid);
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
