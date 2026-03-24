// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {approve as erc6909Approve} from "src/token/ERC6909/Approve/ERC6909ApproveMod.sol";

/**
 * @notice Exposes ERC6909ApproveMod `approve` for tests.
 */
contract ERC6909ApproveModHarness {
    function approve(address spender, uint256 id, uint256 amount) external {
        erc6909Approve(spender, id, amount);
    }
}
