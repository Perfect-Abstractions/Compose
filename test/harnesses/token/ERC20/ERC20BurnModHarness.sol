// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC20/Burn/ERC20BurnMod.sol" as ERC20BurnMod;

/**
 * @title ERC20BurnModHarness
 * @notice Test harness that exposes ERC20BurnMod functions as external
 */
contract ERC20BurnModHarness {
    /**
     * @notice Exposes ERC20BurnMod.burnERC20 as an external function
     */
    function burn(address _account, uint256 _value) external {
        ERC20BurnMod.burnERC20(_account, _value);
    }
}
