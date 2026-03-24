// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909ApproveMod_Base_Test} from "test/unit/token/ERC6909/Approve/ERC6909ApproveModBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Approve_ERC6909ApproveMod_Fuzz_Test is ERC6909ApproveMod_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_ShouldSetAllowance_Approve(address spender, uint256 id, uint256 amount) external {
        vm.assume(spender != address(0));
        vm.stopPrank();
        vm.prank(users.alice);
        harness.approve(spender, id, amount);
        assertEq(address(harness).allowance(users.alice, spender, id), amount, "allowance");
    }
}
