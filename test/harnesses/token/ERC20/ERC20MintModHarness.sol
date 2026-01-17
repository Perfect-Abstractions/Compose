// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC20/Mint/ERC20MintMod.sol" as ERC20MintMod;

/**
 * @title ERC20MintModHarness
 * @notice Test harness that exposes ERC20MintMod functions as external
 */
contract ERC20MintModHarness {
    /**
     * @notice Exposes ERC20Mod.mintERC20 as an external function
     */
    function mint(address _account, uint256 _value) external {
        ERC20MintMod.mintERC20(_account, _value);
    }
}
