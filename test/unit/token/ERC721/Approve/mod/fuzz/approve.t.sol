// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721ApproveMod_Base_Test} from "test/unit/token/ERC721/Approve/ERC721ApproveModBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import "src/token/ERC721/Approve/ERC721ApproveMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Approve_ERC721ApproveMod_Fuzz_Unit_Test is ERC721ApproveMod_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_Approve_WhenTokenDoesNotExist(address to, uint256 tokenId) external {
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        harness.approve(to, tokenId);
    }

    function testFuzz_ShouldApprove_WhenTokenExists(address owner, address to, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(harness).mint(owner, tokenId);

        vm.expectEmit(address(harness));
        emit Approval(owner, to, tokenId);
        harness.approve(to, tokenId);

        assertEq(address(harness).getApproved(tokenId), to, "approved(tokenId)");
    }

    function testFuzz_ShouldRevert_SetApprovalForAll_WhenOperatorIsZeroAddress(address user, bool approved) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidOperator.selector, address(0)));
        harness.setApprovalForAll(user, address(0), approved);
    }

    function testFuzz_ShouldSetApprovalForAll_WhenOperatorIsNotZeroAddress(
        address user,
        address operator,
        bool approved
    ) external {
        vm.assume(operator != address(0));

        vm.expectEmit(address(harness));
        emit ApprovalForAll(user, operator, approved);
        harness.setApprovalForAll(user, operator, approved);

        bool result = address(harness).isApprovedForAll(user, operator);
        assertEq(result, approved, "isApprovedForAll(user, operator)");
    }
}

