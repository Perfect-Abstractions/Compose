// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909ApproveFacet_Base_Test} from "test/unit/token/ERC6909/Approve/ERC6909ApproveFacetBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909ApproveFacet} from "src/token/ERC6909/Approve/ERC6909ApproveFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Approve_ERC6909ApproveFacet_Fuzz_Test is ERC6909ApproveFacet_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_RevertWhen_SpenderZero_Approve(uint256 id, uint256 amount) external {
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909ApproveFacet.ERC6909InvalidSpender.selector, address(0)));
        facet.approve(address(0), id, amount);
    }

    function testFuzz_ShouldSetAllowanceAndEmit_Approve(address spender, uint256 id, uint256 amount) external {
        vm.assume(spender != address(0));
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit ERC6909ApproveFacet.Approval(users.alice, spender, id, amount);
        facet.approve(spender, id, amount);
        assertEq(address(facet).allowance(users.alice, spender, id), amount, "allowance");
    }

    function test_ShouldSetAllowanceAndEmit_Approve_WhenAmountZero() external {
        uint256 id = 42;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit ERC6909ApproveFacet.Approval(users.alice, users.bob, id, 0);
        facet.approve(users.bob, id, 0);
        assertEq(address(facet).allowance(users.alice, users.bob, id), 0, "allowance");
    }
}
