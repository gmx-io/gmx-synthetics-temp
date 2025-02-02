// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

// @title WNT
// @dev similar implementation as WETH but since some networks
// might have a different native token we use WNT for a more general reference name
contract WNT is ERC20Permit {
    constructor() ERC20("Wrapped Native Token", "WNT") ERC20Permit("Wrapped Native Token") {}

    error TransferFailed(address account, uint256 amount);

    // @dev mint WNT by depositing the native token
    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    // @dev withdraw the native token by burning WNT
    // @param amount the amount to withdraw
    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool success, ) = msg.sender.call{ value: amount }("");
        if (!success) {
            revert TransferFailed(msg.sender, amount);
        }
    }

    // @dev mint tokens to an account
    // @param account the account to mint to
    // @param amount the amount of tokens to mint
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    // @dev burn tokens from an account
    // @param account the account to burn tokens for
    // @param amount the amount of tokens to burn
    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
