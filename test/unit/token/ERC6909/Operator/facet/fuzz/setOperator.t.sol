// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909OperatorFacet_Base_Test} from "test/unit/token/ERC6909/Operator/ERC6909OperatorFacetBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909OperatorFacet} from "src/token/ERC6909/Operator/ERC6909OperatorFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract SetOperator_ERC6909OperatorFacet_Fuzz_Test is ERC6909OperatorFacet_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_RevertWhen_SpenderZero_SetOperator(bool approved) external {
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909OperatorFacet.ERC6909InvalidSpender.selector, address(0)));
        facet.setOperator(address(0), approved);
    }

    function testFuzz_ShouldSetOperatorAndEmit_SetOperator(address spender, bool approved) external {
        vm.assume(spender != address(0));
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, false, true);
        emit ERC6909OperatorFacet.OperatorSet(users.alice, spender, approved);
        facet.setOperator(spender, approved);
        assertEq(address(facet).isOperator(users.alice, spender), approved, "isOperator");
    }
}
