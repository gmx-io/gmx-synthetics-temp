// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { LayerZeroProvider } from "../multichain/LayerZeroProvider.sol";

contract MockStargatePool {
    function sendToken(address token, address recipientContract, uint256 amount, bytes calldata message) external {
        IERC20(token).transferFrom(msg.sender, recipientContract, amount);

        address from = address(this);
        bytes32 guid = bytes32(0);
        address executor = msg.sender;
        bytes memory extraData = bytes("");

        LayerZeroProvider(recipientContract).lzCompose(from, guid, message, executor, extraData);
    }
}
