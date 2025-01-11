// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {GelatoRelayContextERC2771} from "@gelatonetwork/relay-context/contracts/GelatoRelayContextERC2771.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./BaseRouter.sol";
import "../data/DataStore.sol";
import "../event/EventEmitter.sol";
import "../exchange/IOrderHandler.sol";
import "../external/IExternalHandler.sol";
import "../oracle/OracleModule.sol";
import "../order/IBaseOrderUtils.sol";
import "../order/OrderStoreUtils.sol";
import "../order/OrderVault.sol";
import "../router/Router.sol";
import "../token/TokenUtils.sol";
import "../swap/SwapUtils.sol";
import "../nonce/NonceUtils.sol";

/*

1. base case with GelatoRelayContextERC2771

function _abiEncodeCallWithSyncFeeERC2771(
    CallWithERC2771 calldata _call
) internal pure returns (bytes memory) {
    return
        abi.encode(
            CALL_WITH_SYNC_FEE_ERC2771_TYPEHASH,
            _call.chainId,
            _call.target,
            keccak256(_call.data),
            _call.user,
            _call.userNonce,
            _call.userDeadline
        );
}

UI:
message = abi.encode(
    orderParams,
    nonce
)
messageHash = keccak256(message)
signature = sign(messageHash)
orderActionCalldata = abi.encode(
    orderParams,
    nonce,
    v,
    r,
    s
)

Contracts:
orderAction = abi.decode(orderActionCalldata, (bytes, uint256, uint8, bytes32, bytes32))
message = abi.encode(
    orderAction,
    signature
)
messageHash = keccak256(message)
address = erecover(messageHash, v, r, s)

*/

contract GelatoRelayRouter is GelatoRelayContextERC2771, BaseRouter, OracleModule {
    using Order for Order.Props;

    IOrderHandler public immutable orderHandler;
    IExternalHandler public immutable externalHandler;
    OrderVault public immutable orderVault;

    struct PermitParams {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        address token;
    }

    struct FeeParams {
        address feeToken;
        uint256 feeAmount;
        address[] feeSwapPath;
    }

    struct BaseParams {
        OracleUtils.SetPricesParams oracleParams;
        PermitParams[] permitParams;
        FeeParams feeParams;
    }

    struct UpdateOrderParams {
        uint256 sizeDeltaUsd;
        uint256 acceptablePrice;
        uint256 triggerPrice;
        uint256 minOutputAmount;
        uint256 validFromTime;
        bool autoCancel;
    }

    struct Contracts {
        DataStore dataStore;
        EventEmitter eventEmitter;
        OrderVault orderVault;
    }

    constructor(
        Router _router,
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        IOrderHandler _orderHandler,
        OrderVault _orderVault,
        IExternalHandler _externalHandler
    ) BaseRouter(_router, _roleStore, _dataStore, _eventEmitter) OracleModule(_oracle) {
        orderHandler = _orderHandler;
        externalHandler = _externalHandler;
        orderVault = _orderVault;
    }

    function multicall(bytes[] calldata) external payable virtual override returns (bytes[] memory) {
        // disable multicall for safety
        // https://docs.gelato.network/web3-services/relay/security-considerations/erc-2771-delegatecall-vulnerability#avoid-multicall-in-combination-with-erc-2771
        revert Errors.NotImplemented();
    }

    function createOrderWithSignature(
        BaseParams calldata baseParams,
        uint256 collateralAmount,
        IBaseOrderUtils.CreateOrderParams memory params, // can't use calldata because need to modify params.numbers.executionFee
        address account,
        bytes memory signature
    ) external nonReentrant withOraclePricesForAtomicAction(baseParams.oracleParams) returns (bytes32) {
        // TODO add custom nonce to protect from replay attacks
        bytes memory message = _getCreateOrderSignatureMessage(baseParams, collateralAmount, params);
        _validateSignature(message, signature, account);
        return _createOrder(baseParams.permitParams, baseParams.feeParams, collateralAmount, params, account);
    }

    function createOrder(
        BaseParams calldata baseParams,
        uint256 collateralAmount,
        IBaseOrderUtils.CreateOrderParams memory params // can't use calldata because need to modify params.numbers.executionFee
    ) external nonReentrant withOraclePricesForAtomicAction(baseParams.oracleParams) onlyGelatoRelayERC2771 returns (bytes32) {
        // should not use msg.sender directly because Gelato relayer passes it in calldata
        address account = _getMsgSender();
        return _createOrder(baseParams.permitParams, baseParams.feeParams, collateralAmount, params, account);
    }

    function updateOrder(
        BaseParams calldata baseParams,
        bytes32 key,
        UpdateOrderParams calldata params
    ) external nonReentrant withOraclePricesForAtomicAction(baseParams.oracleParams) onlyGelatoRelayERC2771 {
        // should not use msg.sender directly because Gelato relayer passes it in calldata
        address account = _getMsgSender();

        Contracts memory contracts = Contracts({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            orderVault: orderVault
        });

        Order.Props memory order = OrderStoreUtils.get(contracts.dataStore, key);
        if (order.account() != account) {
            revert Errors.Unauthorized(account, "account for updateOrder");
        }

        _processPermits(baseParams.permitParams);
        _processFee(contracts, baseParams.feeParams, key, order.uiFeeReceiver(), account);

        orderHandler.updateOrder(
            key,
            params.sizeDeltaUsd,
            params.acceptablePrice,
            params.triggerPrice,
            params.minOutputAmount,
            params.validFromTime,
            params.autoCancel,
            order
        );
    }

    function cancelOrder(
        BaseParams calldata baseParams,
        bytes32 key
    ) external nonReentrant withOraclePricesForAtomicAction(baseParams.oracleParams) onlyGelatoRelayERC2771 {
        Order.Props memory order = OrderStoreUtils.get(dataStore, key);
        if (order.account() == address(0)) {
            revert Errors.EmptyOrder();
        }

        // should not use msg.sender directly because Gelato relayer passes it in calldata
        address account = _getMsgSender();

        if (order.account() != account) {
            revert Errors.Unauthorized(account, "account for cancelOrder");
        }

        Contracts memory contracts = Contracts({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            orderVault: orderVault
        });

        _processPermits(baseParams.permitParams);
        _processFee(contracts, baseParams.feeParams, key, order.uiFeeReceiver(), account);

        orderHandler.cancelOrder(key);
    }

    function _getCreateOrderSignatureMessage(
        BaseParams memory baseParams,
        uint256 collateralAmount,
        IBaseOrderUtils.CreateOrderParams memory params
    ) internal pure returns (bytes memory) {
        return abi.encode(baseParams, collateralAmount, params);
    }

    function _validateSignature(bytes memory message, bytes memory signature, address account) internal pure {
        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(message));
        address recoveredSigner = ECDSA.recover(digest, signature);

        // TODO at first glance the validation is not even necessary. recovered signer can just be used as account?
        if (recoveredSigner != account) {
            revert Errors.InvalidAccount(recoveredSigner, account);
        }
    }

    function _createOrder(
        PermitParams[] calldata permitParams,
        FeeParams calldata feeParams,
        uint256 collateralAmount,
        IBaseOrderUtils.CreateOrderParams memory params, // can't use calldata because need to modify params.numbers.executionFee
        address account
    ) internal returns (bytes32) {
        if (params.addresses.receiver != account) {
            // otherwise malicious relayer can set receiver to any address and steal user's funds
            revert Errors.InvalidReceiver(params.addresses.receiver);
        }

        Contracts memory contracts = Contracts({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            orderVault: orderVault
        });

        _processPermits(permitParams);
        params.numbers.executionFee = _processFee(
            contracts,
            feeParams,
            NonceUtils.getNextKey(contracts.dataStore), // order key
            params.addresses.uiFeeReceiver,
            address(contracts.orderVault)
        );

        if (collateralAmount > 0) {
            _sendTokens(
                account,
                params.addresses.initialCollateralToken,
                address(contracts.orderVault),
                collateralAmount
            );
        }

        return orderHandler.createOrder(account, params);
    }

    function _processFee(
        Contracts memory contracts,
        FeeParams calldata feeParams,
        bytes32 orderKey,
        address uiFeeReceiver,
        address residualFeeReceiver
    ) internal returns (uint256) {
        address wnt = TokenUtils.wnt(contracts.dataStore);

        if (_getFeeToken() != wnt) {
            revert Errors.InvalidFeeToken(feeParams.feeToken, wnt);
        }

        // should not use msg.sender directly because Gelato relayer passes it in calldata
        address account = _getMsgSender();

        _sendTokens(account, feeParams.feeToken, address(contracts.orderVault), feeParams.feeAmount);
        uint256 outputAmount = _swapFeeTokens(contracts, wnt, feeParams, orderKey, uiFeeReceiver);
        // TODO if Gelato accepts native token then it should be unwrapped in the swap
        _transferRelayFee();

        uint256 residualFee = outputAmount - _getFee();
        TokenUtils.transfer(contracts.dataStore, wnt, residualFeeReceiver, residualFee);
        return residualFee;
    }

    function _swapFeeTokens(
        Contracts memory contracts,
        address wnt,
        FeeParams calldata feeParams,
        bytes32 orderKey,
        address uiFeeReceiver
    ) internal returns (uint256) {
        // swap fee tokens to WNT
        Market.Props[] memory swapPathMarkets = MarketUtils.getSwapPathMarkets(
            contracts.dataStore,
            feeParams.feeSwapPath
        );

        (address outputToken, uint256 outputAmount) = SwapUtils.swap(
            SwapUtils.SwapParams({
                dataStore: contracts.dataStore,
                eventEmitter: contracts.eventEmitter,
                oracle: oracle,
                bank: contracts.orderVault,
                key: orderKey,
                tokenIn: feeParams.feeToken,
                amountIn: feeParams.feeAmount,
                swapPathMarkets: swapPathMarkets,
                minOutputAmount: _getFee(),
                receiver: address(this),
                uiFeeReceiver: uiFeeReceiver,
                shouldUnwrapNativeToken: false
            })
        );

        if (outputToken != wnt) {
            revert Errors.InvalidSwapOutputToken(outputToken, wnt);
        }

        return outputAmount;
    }

    function _processPermits(PermitParams[] memory permitParams) internal {
        // not all tokens support ERC20Permit, for them separate transaction is needed
        address _router = address(router);

        for (uint256 i; i < permitParams.length; i++) {
            PermitParams memory permit = permitParams[i];

            if (permit.spender != _router) {
                // to avoid permitting spending by an incorrect spender for extra safety
                revert Errors.InvalidPermitSpender(permit.spender, _router);
            }

            if (ERC20(permit.token).allowance(permit.owner, permit.spender) >= permit.value) {
                // allowance is already sufficient
                continue;
            }

            IERC20Permit(permit.token).permit(
                permit.owner,
                permit.spender,
                permit.value,
                permit.deadline,
                permit.v,
                permit.r,
                permit.s
            );
        }
    }

    function _sendTokens(address account, address token, address receiver, uint256 amount) internal {
        AccountUtils.validateReceiver(receiver);
        router.pluginTransfer(token, account, receiver, amount);
    }
}
