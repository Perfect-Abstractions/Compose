// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155ApproveFacet_Base_Test} from "test/unit/token/ERC1155/Approve/ERC1155ApproveFacetBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155ApproveFacet} from "src/token/ERC1155/Approve/ERC1155ApproveFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract SetApprovalForAll_ERC1155ApproveFacet_Fuzz_Test is ERC1155ApproveFacet_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_SetApprovalForAll_WhenOperatorIsZeroAddress(bool approved) external {
        vm.stopPrank();
        vm.expectRevert(abi.encodeWithSelector(ERC1155ApproveFacet.ERC1155InvalidOperator.selector, address(0)));
        vm.prank(users.alice);
        facet.setApprovalForAll(address(0), approved);
    }

    function testFuzz_ShouldSetApprovalAndEmit_SetApprovalForAll_WhenOperatorNotZero(address operator, bool approved)
        external
    {
        vm.assume(operator != address(0));
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(address(facet));
        emit ERC1155ApproveFacet.ApprovalForAll(users.alice, operator, approved);
        facet.setApprovalForAll(operator, approved);
        assertEq(address(facet).isApprovedForAll(users.alice, operator), approved, "isApprovedForAll");
    }
}
