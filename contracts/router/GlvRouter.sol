// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "./BaseRouter.sol";
import "../exchange/IGlvHandler.sol";
import "../external/IExternalHandler.sol";

contract GlvRouter is BaseRouter {
    using GlvDeposit for GlvDeposit.Props;
    using GlvWithdrawal for GlvWithdrawal.Props;

    IGlvHandler public immutable glvHandler;
    IExternalHandler public immutable externalHandler;

    constructor(
        Router _router,
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        IGlvHandler _glvHandler,
        IExternalHandler _externalHandler
    ) BaseRouter(_router, _roleStore, _dataStore, _eventEmitter) {
        glvHandler = _glvHandler;
        externalHandler = _externalHandler;
    }

    receive() external payable {
        address wnt = TokenUtils.wnt(dataStore);
        if (msg.sender != wnt) {
            revert Errors.InvalidNativeTokenSender(msg.sender);
        }
    }

    function createGlvDeposit(
        GlvDepositUtils.CreateGlvDepositParams calldata params
    ) external payable nonReentrant returns (bytes32) {
        address account = msg.sender;

        return glvHandler.createGlvDeposit(account, params);
    }

    function cancelGlvDeposit(bytes32 key) external nonReentrant {
        GlvDeposit.Props memory glvDeposit = GlvDepositStoreUtils.get(dataStore, key);
        if (glvDeposit.account() == address(0)) {
            revert Errors.EmptyGlvDeposit();
        }

        if (glvDeposit.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelGlvDeposit");
        }

        glvHandler.cancelGlvDeposit(key);
    }

    function simulateExecuteGlvDeposit(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        glvHandler.simulateExecuteGlvDeposit(key, simulatedOracleParams);
    }

    function simulateExecuteLatestGlvDeposit(
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        bytes32 key = NonceUtils.getCurrentKey(dataStore);
        glvHandler.simulateExecuteGlvDeposit(key, simulatedOracleParams);
    }

    function createGlvWithdrawal(
        GlvWithdrawalUtils.CreateGlvWithdrawalParams calldata params
    ) external payable nonReentrant returns (bytes32) {
        address account = msg.sender;

        return glvHandler.createGlvWithdrawal(account, params);
    }

    function cancelGlvWithdrawal(bytes32 key) external nonReentrant {
        GlvWithdrawal.Props memory glvWithdrawal = GlvWithdrawalStoreUtils.get(dataStore, key);
        if (glvWithdrawal.account() == address(0)) {
            revert Errors.EmptyGlvWithdrawal();
        }

        if (glvWithdrawal.account() != msg.sender) {
            revert Errors.Unauthorized(msg.sender, "account for cancelGlvWithdrawal");
        }

        glvHandler.cancelGlvWithdrawal(key);
    }

    function simulateExecuteGlvWithdrawal(
        bytes32 key,
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        glvHandler.simulateExecuteGlvWithdrawal(key, simulatedOracleParams);
    }

    function simulateExecuteLatestGlvWithdrawal(
        OracleUtils.SimulatePricesParams memory simulatedOracleParams
    ) external payable nonReentrant {
        bytes32 key = NonceUtils.getCurrentKey(dataStore);
        glvHandler.simulateExecuteGlvWithdrawal(key, simulatedOracleParams);
    }

    // makeExternalCalls can be used to perform an external swap before
    // an action
    // example:
    // - ExchangeRouter.sendTokens(token: WETH, receiver: externalHandler, amount: 1e18)
    // - ExchangeRouter.makeExternalCalls(
    //     WETH.approve(spender: aggregator, amount: 1e18),
    //     aggregator.swap(amount: 1, from: WETH, to: USDC, receiver: orderHandler)
    // )
    // - ExchangeRouter.createOrder
    // the msg.sender for makeExternalCalls would be externalHandler
    // refundTokens can be used to retrieve any excess tokens that may
    // be left in the externalHandler
    function makeExternalCalls(
        address[] memory externalCallTargets,
        bytes[] memory externalCallDataList,
        address[] memory refundTokens,
        address[] memory refundReceivers
    ) external payable nonReentrant {
        externalHandler.makeExternalCalls(
            externalCallTargets,
            externalCallDataList,
            refundTokens,
            refundReceivers
        );
    }
}
