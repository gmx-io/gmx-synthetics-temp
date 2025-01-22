// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "../order/IBaseOrderUtils.sol";
import "../router/Router.sol";
import "../feature/FeatureUtils.sol";
import "../subaccount/SubaccountUtils.sol";
import "./BaseGelatoRelayRouterNonERC2771.sol";

contract SubaccountGelatoRelayRouterNonERC2771 is BaseGelatoRelayRouterNonERC2771 {
    struct SubaccountApproval {
        address subaccount;
        uint256 expiresAt;
        uint256 maxAllowedCount;
        bytes32 actionType;
        uint256 deadline;
        uint256 nonce; // for replay attack protection
        bytes signature;
    }

    bytes32 public constant UPDATE_ORDER_TYPEHASH =
        keccak256(
            bytes(
                "UpdateOrder(bytes32 key,UpdateOrderParams params,uint256 userNonce,uint256 deadline,bytes32 relayParams,bytes32 subaccountApproval)"
            )
        );
    bytes32 public constant UPDATE_ORDER_PARAMS_TYPEHASH =
        keccak256(
            bytes(
                "UpdateOrderParams(uint256 sizeDeltaUsd,uint256 acceptablePrice,uint256 triggerPrice,uint256 minOutputAmount,uint256 validFromTime,bool autoCancel)"
            )
        );

    bytes32 public constant CANCEL_ORDER_TYPEHASH =
        keccak256(
            bytes(
                "CancelOrder(bytes32 key,uint256 userNonce,uint256 deadline,bytes32 relayParams,bytes32 subaccountApproval)"
            )
        );

    bytes32 public constant CREATE_ORDER_TYPEHASH =
        keccak256(
            bytes(
                "CreateOrder(uint256 collateralAmount,CreateOrderAddresses addresses,CreateOrderNumbers numbers,uint256 orderType,bool isLong,bool shouldUnwrapNativeToken,bool autoCancel,uint256 referralCode,uint256 userNonce,uin256 deadline,bytes32 relayParams,bytes32 subaccountApproval)CreateOrderAddresses(address receiver,address cancellationReceiver,address callbackContract,address uiFeeReceiver,address market,address initialCollateralToken,address[] swapPath)CreateOrderNumbers(uint256 sizeDeltaUsd,uint256 initialCollateralDeltaAmount,uint256 triggerPrice,uint256 acceptablePrice,uint256 executionFee,uint256 callbackGasLimit,uint256 minOutputAmount,uint256 validFromTime)"
            )
        );
    bytes32 public constant CREATE_ORDER_NUMBERS_TYPEHASH =
        keccak256(
            bytes(
                "CreateOrderNumbers(uint256 sizeDeltaUsd,uint256 initialCollateralDeltaAmount,uint256 triggerPrice,uint256 acceptablePrice,uint256 executionFee,uint256 callbackGasLimit,uint256 minOutputAmount,uint256 validFromTime)"
            )
        );
    bytes32 public constant CREATE_ORDER_ADDRESSES_TYPEHASH =
        keccak256(
            bytes(
                "CreateOrderAddresses(address receiver,address cancellationReceiver,address callbackContract,address uiFeeReceiver,address market,address initialCollateralToken,address[] swapPath)"
            )
        );

    bytes32 public constant SUBACCOUNT_APPROVAL_TYPEHASH =
        keccak256(
            bytes(
                "SubaccountGelatoRelayRouter_SubaccountApproval(address subaccount,uint256 expiresAt,uint256 maxAllowedCount,bytes32 actionType,uint256 nonce,bytes signature)"
            )
        );

    mapping(address => uint256) public subaccountApprovalNonces;

    constructor(
        Router _router,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        IOrderHandler _orderHandler,
        OrderVault _orderVault
    ) BaseGelatoRelayRouterNonERC2771(_router, _dataStore, _eventEmitter, _oracle, _orderHandler, _orderVault) {}

    function createOrder(
        RelayParams calldata relayParams,
        SubaccountApproval calldata subaccountApproval,
        uint256 collateralAmount,
        IBaseOrderUtils.CreateOrderParams memory params, // can't use calldata because need to modify params.numbers.executionFee
        address account,
        address subaccount,
        bytes calldata signature,
        uint256 userNonce,
        uint256 deadline
    )
        external
        nonReentrant
        withOraclePricesForAtomicAction(relayParams.oracleParams)
        onlyGelatoRelay
        returns (bytes32)
    {
        bytes32 structHash = _getCreateOrderStructHash(
            relayParams,
            subaccountApproval,
            collateralAmount,
            params,
            userNonce,
            deadline
        );
        _validateCall(userNonce, deadline, account, structHash, signature);
        _validateSubaccountAction(account, subaccount, Keys.SUBACCOUNT_ORDER_ACTION, subaccountApproval);

        return _createOrder(relayParams.tokenPermit, relayParams.fee, collateralAmount, params, account);
    }

    function updateOrder(
        RelayParams calldata relayParams,
        SubaccountApproval calldata subaccountApproval,
        address account,
        address subaccount,
        bytes32 key,
        UpdateOrderParams calldata params,
        bytes calldata signature,
        uint256 userNonce,
        uint256 deadline
    ) external nonReentrant withOraclePricesForAtomicAction(relayParams.oracleParams) onlyGelatoRelay {
        bytes32 structHash = _getUpdateOrderStructHash(
            relayParams,
            subaccountApproval,
            key,
            params,
            userNonce,
            deadline
        );
        _validateCall(userNonce, deadline, account, structHash, signature);
        _validateSubaccountAction(account, subaccount, Keys.SUBACCOUNT_ORDER_ACTION, subaccountApproval);
        _updateOrder(relayParams, account, key, params);
    }

    function cancelOrder(
        RelayParams calldata relayParams,
        SubaccountApproval calldata subaccountApproval,
        address account,
        address subaccount,
        bytes32 key,
        bytes calldata signature,
        uint256 userNonce,
        uint256 deadline
    ) external nonReentrant withOraclePricesForAtomicAction(relayParams.oracleParams) onlyGelatoRelay {
        bytes32 structHash = _getCancelOrderStructHash(relayParams, subaccountApproval, key, userNonce, deadline);
        _validateCall(userNonce, deadline, account, structHash, signature);
        _validateSubaccountAction(account, subaccount, Keys.SUBACCOUNT_ORDER_ACTION, subaccountApproval);
        _cancelOrder(relayParams, account, key);
    }

    function _validateSubaccountAction(
        address account,
        address subaccount,
        bytes32 actionType,
        SubaccountApproval calldata subaccountApproval
    ) internal {
        FeatureUtils.validateFeature(dataStore, Keys.subaccountFeatureDisabledKey(address(this)));

        _handleSubaccountApproval(account, subaccount, subaccountApproval);

        SubaccountUtils.validateSubaccount(dataStore, account, subaccount);

        SubaccountUtils.incrementSubaccountActionCount(dataStore, eventEmitter, account, subaccount, actionType);
    }

    function _handleSubaccountApproval(address account, address subaccount, SubaccountApproval calldata subaccountApproval) internal {
        if (subaccountApproval.signature.length == 0) {
            return;
        }

        if (subaccountApproval.deadline > 0 && block.timestamp > subaccountApproval.deadline) {
            revert Errors.SubaccountApprovalDeadlinePassed(block.timestamp, subaccountApproval.deadline);
        }

        uint256 storedNonce = subaccountApprovalNonces[account];
        if (storedNonce != subaccountApproval.nonce) {
            revert Errors.InvalidSubaccountApprovalNonce(storedNonce, subaccountApproval.nonce);
        }
        subaccountApprovalNonces[account] = storedNonce + 1;

        bytes32 domainSeparator = _getDomainSeparator(block.chainid);
        bytes32 structHash = _getSubaccountApprovalStructHash(subaccountApproval);
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);
        _validateSignature(digest, subaccountApproval.signature, account);

        if (subaccountApproval.maxAllowedCount > 0) {
            SubaccountUtils.setMaxAllowedSubaccountActionCount(
                dataStore,
                eventEmitter,
                account,
                subaccountApproval.subaccount,
                subaccountApproval.actionType,
                subaccountApproval.maxAllowedCount
            );
        }

        if (subaccountApproval.expiresAt > 0) {
            SubaccountUtils.setSubaccountExpiresAt(
                dataStore,
                eventEmitter,
                account,
                subaccountApproval.subaccount,
                subaccountApproval.actionType,
                subaccountApproval.expiresAt
            );
        }

        if (subaccountApproval.subaccount != address(0)) {
            if (subaccountApproval.subaccount != subaccount) {
                revert Errors.InvalidSubaccount(subaccountApproval.subaccount, subaccount);
            }

            SubaccountUtils.addSubaccount(dataStore, eventEmitter, account, subaccountApproval.subaccount);
        }
    }

    function _getSubaccountApprovalStructHash(
        SubaccountApproval calldata subaccountApproval
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    SUBACCOUNT_APPROVAL_TYPEHASH,
                    subaccountApproval.subaccount,
                    subaccountApproval.expiresAt,
                    subaccountApproval.maxAllowedCount,
                    subaccountApproval.actionType,
                    subaccountApproval.nonce
                )
            );
    }

    function _getCreateOrderStructHash(
        RelayParams calldata relayParams,
        SubaccountApproval calldata subaccountApproval,
        uint256 collateralAmount,
        IBaseOrderUtils.CreateOrderParams memory params,
        uint256 userNonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CREATE_ORDER_TYPEHASH,
                    collateralAmount,
                    _getCreateOrderAddressesStructHash(params.addresses),
                    _getCreateOrderNumbersStructHash(params.numbers),
                    uint256(params.orderType),
                    params.isLong,
                    params.shouldUnwrapNativeToken,
                    params.autoCancel,
                    params.referralCode,
                    keccak256(abi.encode(relayParams)),
                    keccak256(abi.encode(subaccountApproval)),
                    userNonce,
                    deadline
                )
            );
    }

    function _getCreateOrderAddressesStructHash(
        IBaseOrderUtils.CreateOrderParamsAddresses memory addresses
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CREATE_ORDER_ADDRESSES_TYPEHASH,
                    addresses.receiver,
                    addresses.cancellationReceiver,
                    addresses.callbackContract,
                    addresses.uiFeeReceiver,
                    addresses.market,
                    addresses.initialCollateralToken,
                    keccak256(abi.encodePacked(addresses.swapPath))
                )
            );
    }

    function _getCreateOrderNumbersStructHash(
        IBaseOrderUtils.CreateOrderParamsNumbers memory numbers
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CREATE_ORDER_NUMBERS_TYPEHASH,
                    numbers.sizeDeltaUsd,
                    numbers.initialCollateralDeltaAmount,
                    numbers.triggerPrice,
                    numbers.acceptablePrice,
                    numbers.executionFee,
                    numbers.callbackGasLimit,
                    numbers.minOutputAmount,
                    numbers.validFromTime
                )
            );
    }

    function _getUpdateOrderStructHash(
        RelayParams calldata relayParams,
        SubaccountApproval calldata subaccountApproval,
        bytes32 key,
        UpdateOrderParams calldata params,
        uint256 userNonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    UPDATE_ORDER_TYPEHASH,
                    key,
                    _getUpdateOrderParamsStructHash(params),
                    userNonce,
                    deadline,
                    keccak256(abi.encode(relayParams)),
                    keccak256(abi.encode(subaccountApproval))
                )
            );
    }

    function _getUpdateOrderParamsStructHash(UpdateOrderParams calldata params) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    UPDATE_ORDER_PARAMS_TYPEHASH,
                    params.sizeDeltaUsd,
                    params.acceptablePrice,
                    params.triggerPrice,
                    params.minOutputAmount,
                    params.validFromTime,
                    params.autoCancel
                )
            );
    }

    function _getCancelOrderStructHash(
        RelayParams calldata relayParams,
        SubaccountApproval calldata subaccountApproval,
        bytes32 key,
        uint256 userNonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    CANCEL_ORDER_TYPEHASH,
                    key,
                    userNonce,
                    deadline,
                    keccak256(abi.encode(relayParams)),
                    keccak256(abi.encode(subaccountApproval))
                )
            );
    }
}
