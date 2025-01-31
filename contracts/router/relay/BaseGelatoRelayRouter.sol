// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import {GelatoRelayContext} from "@gelatonetwork/relay-context/contracts/GelatoRelayContext.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../../data/DataStore.sol";
import "../../event/EventEmitter.sol";
import "../../exchange/IOrderHandler.sol";
import "../../oracle/OracleModule.sol";
import "../../order/IBaseOrderUtils.sol";
import "../../order/OrderStoreUtils.sol";
import "../../order/OrderVault.sol";
import "../../router/Router.sol";
import "../../token/TokenUtils.sol";
import "../../swap/SwapUtils.sol";
import "../../nonce/NonceUtils.sol";

abstract contract BaseGelatoRelayRouter is GelatoRelayContext, ReentrancyGuard, OracleModule {
    using Order for Order.Props;

    struct TokenPermit {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        address token;
    }

    struct RelayFeeParams {
        address feeToken;
        uint256 feeAmount;
        address[] feeSwapPath;
    }

    struct RelayParams {
        OracleUtils.SetPricesParams oracleParams;
        TokenPermit[] tokenPermits;
        RelayFeeParams fee;
        uint256 userNonce;
        uint256 deadline;
        bytes signature;
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

    IOrderHandler public immutable orderHandler;
    OrderVault public immutable orderVault;
    Router public immutable router;
    DataStore public immutable dataStore;
    EventEmitter public immutable eventEmitter;

    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256(bytes("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"));

    bytes32 public constant DOMAIN_SEPARATOR_NAME_HASH = keccak256(bytes("GmxBaseGelatoRelayRouter"));
    bytes32 public constant DOMAIN_SEPARATOR_VERSION_HASH = keccak256(bytes("1"));

    mapping(address => uint256) public userNonces;

    constructor(
        Router _router,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        IOrderHandler _orderHandler,
        OrderVault _orderVault
    ) OracleModule(_oracle) {
        orderHandler = _orderHandler;
        orderVault = _orderVault;
        router = _router;
        dataStore = _dataStore;
        eventEmitter = _eventEmitter;
    }

    function _validateSignature(
        bytes32 digest,
        bytes calldata signature,
        address expectedSigner,
        string memory signatureType
    ) internal pure {
        (address recovered, ECDSA.RecoverError error) = ECDSA.tryRecover(digest, signature);
        if (error != ECDSA.RecoverError.NoError || recovered != expectedSigner) {
            revert Errors.InvalidSignature(signatureType);
        }
    }

    function _updateOrder(
        RelayParams calldata relayParams,
        address account,
        bytes32 key,
        UpdateOrderParams calldata params
    ) internal {
        Contracts memory contracts = Contracts({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            orderVault: orderVault
        });

        Order.Props memory order = OrderStoreUtils.get(contracts.dataStore, key);

        if (order.account() == address(0)) {
            revert Errors.EmptyOrder();
        }

        if (order.account() != account) {
            revert Errors.Unauthorized(account, "account for updateOrder");
        }

        _handleRelay(contracts, relayParams.tokenPermits, relayParams.fee, account, key, account);

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

    function _cancelOrder(RelayParams calldata relayParams, address account, bytes32 key) internal {
        Contracts memory contracts = Contracts({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            orderVault: orderVault
        });

        Order.Props memory order = OrderStoreUtils.get(contracts.dataStore, key);
        if (order.account() == address(0)) {
            revert Errors.EmptyOrder();
        }

        if (order.account() != account) {
            revert Errors.Unauthorized(account, "account for cancelOrder");
        }

        _handleRelay(contracts, relayParams.tokenPermits, relayParams.fee, account, key, account);

        orderHandler.cancelOrder(key);
    }

    function _createOrder(
        RelayParams calldata relayParams,
        address account,
        uint256 collateralDeltaAmount,
        IBaseOrderUtils.CreateOrderParams memory params // can't use calldata because need to modify params.numbers.executionFee
    ) internal returns (bytes32) {
        Contracts memory contracts = Contracts({
            dataStore: dataStore,
            eventEmitter: eventEmitter,
            orderVault: orderVault
        });

        params.numbers.executionFee = _handleRelay(
            contracts,
            relayParams.tokenPermits,
            relayParams.fee,
            account,
            NonceUtils.getNextKey(contracts.dataStore), // order key
            address(contracts.orderVault)
        );

        if (
            params.orderType == Order.OrderType.MarketSwap ||
            params.orderType == Order.OrderType.LimitSwap ||
            params.orderType == Order.OrderType.MarketIncrease ||
            params.orderType == Order.OrderType.LimitIncrease ||
            params.orderType == Order.OrderType.StopIncrease
        ) {
            _sendTokens(
                account,
                params.addresses.initialCollateralToken,
                address(contracts.orderVault),
                collateralDeltaAmount
            );
        }

        return orderHandler.createOrder(account, params);
    }

    function _swapFeeTokens(
        Contracts memory contracts,
        address wnt,
        RelayFeeParams calldata fee,
        bytes32 orderKey
    ) internal returns (uint256) {
        if (fee.feeToken == wnt) {
            contracts.orderVault.transferOut(wnt, address(this), fee.feeAmount);
            return fee.feeAmount;
        }

        // swap fee tokens to WNT
        Market.Props[] memory swapPathMarkets = MarketUtils.getSwapPathMarkets(contracts.dataStore, fee.feeSwapPath);

        (address outputToken, uint256 outputAmount) = SwapUtils.swap(
            SwapUtils.SwapParams({
                dataStore: contracts.dataStore,
                eventEmitter: contracts.eventEmitter,
                oracle: oracle,
                bank: contracts.orderVault,
                key: orderKey,
                tokenIn: fee.feeToken,
                amountIn: fee.feeAmount,
                swapPathMarkets: swapPathMarkets,
                minOutputAmount: _getFee(),
                receiver: address(this),
                uiFeeReceiver: address(0),
                shouldUnwrapNativeToken: false
            })
        );

        if (outputToken != wnt) {
            revert Errors.UnexpectedRelayFeeTokenAfterSwap(outputToken, wnt);
        }

        return outputAmount;
    }

    function _handleRelay(
        Contracts memory contracts,
        TokenPermit[] calldata tokenPermits,
        RelayFeeParams calldata fee,
        address account,
        bytes32 orderKey,
        address residualFeeReceiver
    ) internal returns (uint256) {
        _handleTokenPermits(tokenPermits);
        return _handleRelayFee(contracts, fee, account, orderKey, residualFeeReceiver);
    }

    function _handleTokenPermits(TokenPermit[] calldata tokenPermits) internal {
        // not all tokens support ERC20Permit, for them separate transaction is needed

        if (tokenPermits.length == 0) {
            return;
        }

        address _router = address(router);

        for (uint256 i; i < tokenPermits.length; i++) {
            TokenPermit memory permit = tokenPermits[i];

            if (permit.spender != _router) {
                // to avoid permitting spending by an incorrect spender for extra safety
                revert Errors.InvalidPermitSpender(permit.spender, _router);
            }

            if (ERC20(permit.token).allowance(permit.owner, permit.spender) >= permit.value) {
                // allowance is sufficient already
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

    function _handleRelayFee(
        Contracts memory contracts,
        RelayFeeParams calldata fee,
        address account,
        bytes32 orderKey,
        address residualFeeReceiver
    ) internal returns (uint256) {
        address wnt = TokenUtils.wnt(contracts.dataStore);

        if (_getFeeToken() != wnt) {
            revert Errors.UnsupportedRelayFeeToken(_getFeeToken(), wnt);
        }

        _sendTokens(account, fee.feeToken, address(contracts.orderVault), fee.feeAmount);
        uint256 outputAmount = _swapFeeTokens(contracts, wnt, fee, orderKey);

        uint256 requiredRelayFee = _getFee();
        if (requiredRelayFee > outputAmount) {
            revert Errors.InsufficientRelayFee(requiredRelayFee, outputAmount);
        }

        _transferRelayFee();

        uint256 residualFee = outputAmount - requiredRelayFee;
        // for orders the residual fee is sent to the order vault
        // for other actions the residual fee is sent back to the user
        TokenUtils.transfer(contracts.dataStore, wnt, residualFeeReceiver, residualFee);
        return residualFee;
    }

    function _sendTokens(address account, address token, address receiver, uint256 amount) internal {
        AccountUtils.validateReceiver(receiver);
        router.pluginTransfer(token, account, receiver, amount);
    }

    function _getDomainSeparator(uint256 sourceChainId) internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_SEPARATOR_TYPEHASH,
                    DOMAIN_SEPARATOR_NAME_HASH,
                    DOMAIN_SEPARATOR_VERSION_HASH,
                    sourceChainId,
                    address(this)
                )
            );
    }

    function _validateCall(RelayParams calldata relayParams, address account, bytes32 structHash) internal {
        bytes32 domainSeparator = _getDomainSeparator(block.chainid);
        bytes32 digest = ECDSA.toTypedDataHash(domainSeparator, structHash);
        _validateSignature(digest, relayParams.signature, account, "call");

        _validateNonce(account, relayParams.userNonce);
        _validateDeadline(relayParams.deadline);
    }

    function _validateDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) {
            revert Errors.DeadlinePassed(block.timestamp, deadline);
        }
    }

    function _validateNonce(address account, uint256 userNonce) internal {
        if (userNonces[account] != userNonce) {
            revert Errors.InvalidUserNonce(userNonces[account], userNonce);
        }
        userNonces[account] = userNonce + 1;
    }

    function _getRelayParamsHash(RelayParams calldata relayParams) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    relayParams.oracleParams,
                    relayParams.tokenPermits,
                    relayParams.fee,
                    relayParams.userNonce,
                    relayParams.deadline
                )
            );
    }
}
