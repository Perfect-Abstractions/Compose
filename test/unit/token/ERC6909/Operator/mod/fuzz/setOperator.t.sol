// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909OperatorMod_Base_Test} from "test/unit/token/ERC6909/Operator/ERC6909OperatorModBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract SetOperator_ERC6909OperatorMod_Fuzz_Test is ERC6909OperatorMod_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_ShouldSetOperator_SetOperator(address spender, bool approved) external {
        vm.assume(spender != address(0));
        vm.stopPrank();
        vm.prank(users.alice);
        harness.setOperator(spender, approved);
        assertEq(address(harness).isOperator(users.alice, spender), approved, "isOperator");
    }
}
