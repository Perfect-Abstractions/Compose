// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC20/Transfer/ERC20TransferMod.sol" as ERC20TransferMod;

/**
 * @title ERC20TransferModHarness
 * @notice Test harness that exposes ERC20TransferMod functions as external
 */
contract ERC20TransferModHarness {
    /**
     * @notice Exposes ERC20TransferMod.transferFrom as an external function
     */
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        return ERC20TransferMod.transferFrom(_from, _to, _value);
    }

    /**
     * @notice Exposes ERC20TransferMod.transfer as an external function
     */
    function transfer(address _to, uint256 _value) external returns (bool) {
        return ERC20TransferMod.transfer(_to, _value);
    }
}
