// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721DataFacet_Base_Test} from "test/unit/token/ERC721/Data/ERC721DataFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721DataFacet} from "src/token/ERC721/Data/ERC721DataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Data_ERC721DataFacet_Fuzz_Unit_Test is ERC721DataFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldReturnBalanceOf_WhenOwnerIsNonZero(address owner, uint256 count) external {
        vm.assume(owner != address(0));
        count = bound(count, 0, 10);

        /* Seed balances by minting sequential tokenIds to the same owner. */
        for (uint256 i; i < count; i++) {
            address(facet).mint(owner, i + 1);
        }

        uint256 balance = facet.balanceOf(owner);
        assertEq(balance, count, "balanceOf(owner)");
    }

    function testFuzz_ShouldRevertBalanceOf_WhenOwnerIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC721DataFacet.ERC721InvalidOwner.selector, address(0)));
        facet.balanceOf(address(0));
    }

    function testFuzz_ShouldReturnOwnerOf_WhenTokenExists(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        address result = facet.ownerOf(tokenId);
        assertEq(result, owner, "ownerOf(tokenId)");
    }

    function testFuzz_ShouldRevertOwnerOf_WhenTokenDoesNotExist(uint256 tokenId) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721DataFacet.ERC721NonexistentToken.selector, tokenId));
        facet.ownerOf(tokenId);
    }

    function testFuzz_ShouldReturnZeroAddress_GetApproved_WhenNoApproval(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        address approved = facet.getApproved(tokenId);
        assertEq(approved, address(0), "getApproved(tokenId)");
    }

    function testFuzz_ShouldRevert_GetApproved_WhenTokenDoesNotExist(uint256 tokenId) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721DataFacet.ERC721NonexistentToken.selector, tokenId));
        facet.getApproved(tokenId);
    }

    function testFuzz_ShouldReturnIsApprovedForAll(address owner, address operator, bool approved) external {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));

        address(facet).setApprovedForAll(owner, operator, approved);

        bool result = facet.isApprovedForAll(owner, operator);
        assertEq(result, approved, "isApprovedForAll(owner, operator)");
    }

    function testFuzz_ShouldReturnFalse_IsApprovedForAll_WhenNotPreviouslyApproved(address owner, address operator)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(owner != operator);

        bool result = facet.isApprovedForAll(owner, operator);
        assertEq(result, false, "default isApprovedForAll(owner, operator)");
    }
}

