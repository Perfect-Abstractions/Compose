// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC20/Approve/ERC20ApproveMod.sol" as ERC20ApproveMod;

/**
 * @title ERC20ApproveModHarness
 * @notice Test harness that exposes ERC20ApproveMod functions as external
 */
contract ERC20ApproveModHarness {
    /**
     * @notice Exposes ERC20ApproveMod.approve as an external function
     */
    function approve(address _spender, uint256 _value) external returns (bool) {
        return ERC20ApproveMod.approve(_spender, _value);
    }
}
