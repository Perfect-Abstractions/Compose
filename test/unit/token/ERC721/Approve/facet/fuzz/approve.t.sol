// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721ApproveFacet_Base_Test} from "test/unit/token/ERC721/Approve/ERC721ApproveFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721ApproveFacet} from "src/token/ERC721/Approve/ERC721ApproveFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Approve_ERC721ApproveFacet_Fuzz_Unit_Test is ERC721ApproveFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_Approve_WhenTokenDoesNotExist(address to, uint256 tokenId) external {
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721ApproveFacet.ERC721NonexistentToken.selector, tokenId));
        facet.approve(to, tokenId);
    }

    function testFuzz_ShouldRevert_Approve_WhenCallerIsNotOwnerOrOperator(
        address owner,
        address caller,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(caller != owner);
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        vm.stopPrank();
        vm.prank(caller);

        vm.expectRevert(abi.encodeWithSelector(ERC721ApproveFacet.ERC721InvalidApprover.selector, caller));
        facet.approve(to, tokenId);
    }

    function testFuzz_ShouldApprove_WhenCallerIsOwner(address owner, address to, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.Approval(owner, to, tokenId);
        facet.approve(to, tokenId);

        assertEq(address(facet).getApproved(tokenId), to, "approved(tokenId)");
    }

    function testFuzz_ShouldApprove_WhenCallerIsOperator(address owner, address operator, address to, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(operator != owner);
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        address(facet).setApprovedForAll(owner, operator, true);

        vm.stopPrank();
        vm.prank(operator);

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.Approval(owner, to, tokenId);
        facet.approve(to, tokenId);

        assertEq(address(facet).getApproved(tokenId), to, "approved(tokenId)");
    }

    function testFuzz_ShouldRevert_SetApprovalForAll_WhenOperatorIsZeroAddress(bool approved) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721ApproveFacet.ERC721InvalidOperator.selector, address(0)));
        facet.setApprovalForAll(address(0), approved);
    }

    function testFuzz_ShouldSetApprovalForAll_WhenOperatorIsNotCaller(address operator, bool approved) external {
        vm.assume(operator != address(0));

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.ApprovalForAll(users.alice, operator, approved);
        facet.setApprovalForAll(operator, approved);

        bool result = address(facet).isApprovedForAll(users.alice, operator);
        assertEq(result, approved, "isApprovedForAll(caller, operator)");
    }

    function testFuzz_ShouldSetApprovalForAll_WhenOperatorIsCaller(bool approved) external {
        address caller = users.alice;

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.ApprovalForAll(caller, caller, approved);
        facet.setApprovalForAll(caller, approved);

        bool result = address(facet).isApprovedForAll(caller, caller);
        assertEq(result, approved, "isApprovedForAll(caller, caller)");
    }
}

