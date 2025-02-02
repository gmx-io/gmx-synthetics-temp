// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILayerZeroComposer } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroComposer.sol";

import { EventEmitter } from "../event/EventEmitter.sol";

import { IMultichainProvider } from "./IMultichainProvider.sol";
import { MultichainVault } from "./MultichainVault.sol";
import { MultichainVaultHandler } from "./MultichainVaultHandler.sol";
import { MultichainProviderUtils } from "./MultichainProviderUtils.sol";
import { LayerZeroProviderEventUtils } from "./LayerZeroProviderEventUtils.sol";

/**
 * @title LayerZeroProvider
 * Receives tokens and messages from source chains.
 * Defines lzCompose function which:
 *  - is called by the Stargate executor after tokens are delivered to this contract
 *  - forwards the received tokens to MultichainVault and records the deposit in MultichainVaultHandler
 */
contract LayerZeroProvider is IMultichainProvider, ILayerZeroComposer {
    EventEmitter public eventEmitter;

    MultichainVault public multichainVault;
    MultichainVaultHandler public multichainVaultHandler;

    /**
     * @param _multichainVault MultichainVaultHandler address
     * @param _multichainVaultHandler MultichainVault address
     */
    constructor(address _eventEmitter, address _multichainVault, address _multichainVaultHandler) {
        eventEmitter = EventEmitter(_eventEmitter);
        multichainVault = MultichainVault(payable(_multichainVault));
        multichainVaultHandler = MultichainVaultHandler(_multichainVaultHandler);
    }

    ///////////////////// Stargate //////////////////////

    /**
     * Called by Stargate after tokens have been delivered to this contract.
     * @dev Non-guarded function caller (i.e. require from == stargatePool AND msg.sender == lzEndpoint)
     *      Anyone (and on behalf of anyone) can call this function to deposit tokens
     *      TBD if this will change
     * @dev Non-guarded token address (i.e. require token == USDC)
     *      Any token can be deposited (not just USDC), but current implementation intended to USDC only
     *      TBD if this will change
     * @param from The address of the sender (i.e. Stargate address, not user's address).
     * @param guid A global unique identifier for tracking the packet.
     * @param message Encoded message. Contains the params needed to record the deposit (account, token, sourceChainId)
     * @param executor The address of the Executor.
     * @param extraData Any extra data or options to trigger on receipt.
     */
    function lzCompose(
        address from,
        bytes32 guid,
        bytes calldata message,
        address executor,
        bytes calldata extraData
    ) external payable {
        (address account, address token, uint256 sourceChainId) = MultichainProviderUtils.decodeDeposit(message);

        _transferToVault(token, address(multichainVault));

        multichainVaultHandler.recordDeposit(account, token, sourceChainId);

        LayerZeroProviderEventUtils.emitComposedMessageReceived(
            eventEmitter,
            sourceChainId,
            account,
            from,
            guid,
            message,
            executor,
            extraData
        );
    }

    function _transferToVault(address token, address to) private {
        uint256 amount = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, amount);
    }
}
