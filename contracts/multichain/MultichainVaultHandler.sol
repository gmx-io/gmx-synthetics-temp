// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { RoleStore } from "../role/RoleStore.sol";
import { RoleModule } from "../role/RoleModule.sol";
import { DataStore } from "../data/DataStore.sol";
import { Keys } from "../data/Keys.sol";
import { Oracle } from "../oracle/Oracle.sol";
import { OracleModule } from "../oracle/OracleModule.sol";
import { EventEmitter } from "../event/EventEmitter.sol";
import { Errors } from "../error/Errors.sol";
import { GlobalReentrancyGuard } from "../utils/GlobalReentrancyGuard.sol";
import { ExchangeRouter } from "../router/ExchangeRouter.sol";

import { MultichainVault } from "./MultichainVault.sol";
import { MultichainUtils } from "./MultichainUtils.sol";
import { MultichainEventUtils } from "./MultichainEventUtils.sol";

/**
 * @title MultichainVaultHandler
 */
contract MultichainVaultHandler is RoleModule, GlobalReentrancyGuard, OracleModule {
    using SafeERC20 for IERC20;

    MultichainVault public multichainVault;
    EventEmitter public eventEmitter;
    ExchangeRouter public exchangeRouter;

    constructor(
        RoleStore _roleStore,
        DataStore _dataStore,
        EventEmitter _eventEmitter,
        Oracle _oracle,
        MultichainVault _multichainVault,
        ExchangeRouter _exchangeRouter
    ) RoleModule(_roleStore) GlobalReentrancyGuard(_dataStore) OracleModule(_oracle) {
        multichainVault = _multichainVault;
        eventEmitter = _eventEmitter;
        exchangeRouter = _exchangeRouter;
    }

    /**
     * Records a deposit from another chain. IMultichainProvider has CONTROLLER role
     * @param account user address on the source chain
     * @param token address of the token being deposited
     * @param sourceChainId chain id of the source chain
     */
    function recordDeposit(
        address account,
        address token,
        uint256 sourceChainId
    ) external onlyController {
        // token should have been transferred to multichainVault by IMultichainProvider
        uint256 amount = multichainVault.recordTransferIn(token);
        if (amount == 0) {
            revert Errors.EmptyMultichainDepositAmount();
        }

        dataStore.incrementUint(Keys.sourceChainBalanceKey(sourceChainId, account, token), amount);

        MultichainEventUtils.emitMultichainDeposit(eventEmitter, token, account, amount, sourceChainId);
    }

    /**
     * @dev transfer the specified amount of tokens from MultichainVault to receiver and decrement multichain account balance
     * @param account the account for which the tokens are transferred and multichain balance decremented
     * @param token the token to transfer
     * @param receiver the account to transfer to
     * @param amount the amount of tokens to transfer
     */
    function pluginTransfer(uint256 chainId, address token, address account, address receiver, uint256 amount) external onlyRouterPlugin { // TODO: confirm access control
        dataStore.decrementUint(Keys.sourceChainBalanceKey(chainId, account, token), amount);
        IERC20(token).safeTransferFrom(address(multichainVault), receiver, amount);
    }

    /**
     * Executes the multicall for the given args
     * The multicall arguments contains the function calls to be executed (e.g. createDeposit, createOrder, createWithdrawal, etc)
     * @param account user address on the source chain
     * @param sourceChainId chain id of the source chain
     * @param multicallArgs array of bytes containing the multicall arguments
     */
    function executeMulticall(
        address account,
        uint256 sourceChainId,
        bytes[] calldata multicallArgs
    ) external onlyController {
        // execute multicall
        exchangeRouter.multicall(multicallArgs);

        MultichainEventUtils.emitMultichainMessage(eventEmitter, account, sourceChainId);
    }

    /**
     * Record a withdrawal to another chain. IMultichainProvider has CONTROLLER role
     * @param account user address on the source chain
     * @param token address of the token being withdrawn
     * @param amount amount of token being withdrawn
     * @param sourceChainId chain id of the source chain
     */
    function recordWithdrawal(
        address account,
        address token,
        uint256 amount,
        uint256 sourceChainId
    ) external onlyController {
        if (amount == 0) {
            revert Errors.EmptyMultichainWithdrawalAmount();
        }

        bytes32 balanceKey = Keys.sourceChainBalanceKey(sourceChainId, account, token);

        uint256 balance = dataStore.getUint(balanceKey);
        if (balance < amount) {
            revert Errors.InsufficientMultichainBalance();
            // TODO: should amount be capped instead of reverting? i.e. amount = balance;
        }

        dataStore.decrementUint(balanceKey, amount);

        // transfer tokens to IMultichainProvider
        multichainVault.transferOut(token, msg.sender, amount);

        MultichainEventUtils.emitMultichainWithdrawal(eventEmitter, token, account, amount, sourceChainId);
    }
}
