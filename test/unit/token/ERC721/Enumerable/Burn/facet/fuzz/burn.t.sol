// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721EnumerableBurnFacet_Base_Test
} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableBurnFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721EnumerableBurnFacet} from "src/token/ERC721/Enumerable/Burn/ERC721EnumerableBurnFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Burn_ERC721EnumerableBurnFacet_Fuzz_Unit_Test is ERC721EnumerableBurnFacet_Base_Test {
    using ERC721StorageUtils for address;

    function _seedOwnerToken(address owner, uint256 tokenId) internal {
        uint256 ownerIndex = address(facet).balanceOf(owner);
        address(facet).setOwnerTokenByIndex(owner, ownerIndex, tokenId);
        address(facet).setOwnerTokensIndex(tokenId, ownerIndex);
        address(facet).setBalanceOf(owner, ownerIndex + 1);

        uint256 globalIndex = address(facet).allTokensLength();
        address(facet).pushAllToken(tokenId);
        address(facet).setAllTokensIndex(tokenId, globalIndex);
        address(facet).setOwnerOf(tokenId, owner);
    }

    function testFuzz_ShouldRevert_Burn_WhenTokenDoesNotExist(uint256 tokenId) external {
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableBurnFacet.ERC721NonexistentToken.selector, tokenId));
        facet.burn(tokenId);
    }

    function testFuzz_ShouldRevert_Burn_WhenCallerNotOwnerOrApproved(address owner, address caller, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(caller != address(0));
        vm.assume(caller != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);

        vm.stopPrank();
        vm.prank(caller);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableBurnFacet.ERC721InsufficientApproval.selector, caller, tokenId)
        );
        facet.burn(tokenId);
    }

    function testFuzz_ShouldUpdateEnumerationOnBurn_WhenCallerIsOwner(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(address(facet));
        emit ERC721EnumerableBurnFacet.Transfer(owner, address(0), tokenId);
        facet.burn(tokenId);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
        assertEq(address(facet).allTokensLength(), 0, "totalSupply");
    }

    function testFuzz_ShouldBurn_WhenCallerIsTokenApproved(address owner, address approved, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(approved != address(0));
        vm.assume(approved != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        address(facet).setApproved(tokenId, approved);

        vm.stopPrank();
        vm.prank(approved);

        vm.expectEmit(address(facet));
        emit ERC721EnumerableBurnFacet.Transfer(owner, address(0), tokenId);
        facet.burn(tokenId);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
        assertEq(address(facet).allTokensLength(), 0, "totalSupply");
    }

    function testFuzz_ShouldBurn_WhenCallerIsOperator(address owner, address operator, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(operator != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);
        address(facet).setApprovedForAll(owner, operator, true);

        vm.stopPrank();
        vm.prank(operator);

        vm.expectEmit(address(facet));
        emit ERC721EnumerableBurnFacet.Transfer(owner, address(0), tokenId);
        facet.burn(tokenId);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
        assertEq(address(facet).allTokensLength(), 0, "totalSupply");
    }

    function test_ShouldUpdateEnumerationOnBurn_WhenTokenNotLastInOwnerAndAllTokens() external {
        address owner = users.alice;

        uint256 tokenId1 = 1;
        uint256 tokenId2 = 2;
        uint256 tokenId3 = 3;

        _seedOwnerToken(owner, tokenId1);
        _seedOwnerToken(owner, tokenId2);
        _seedOwnerToken(owner, tokenId3);

        vm.stopPrank();
        vm.prank(owner);
        facet.burn(tokenId2);

        assertEq(address(facet).balanceOf(owner), 2, "owner balance after burn");
        assertEq(address(facet).ownerTokenByIndex(owner, 0), tokenId1, "owner token index 0");
        assertEq(address(facet).ownerTokenByIndex(owner, 1), tokenId3, "owner token index 1");
        assertEq(address(facet).ownerTokensIndex(tokenId1), 0, "ownerTokensIndex tokenId1");
        assertEq(address(facet).ownerTokensIndex(tokenId3), 1, "ownerTokensIndex tokenId3");

        assertEq(address(facet).allTokensLength(), 2, "allTokens length");
        // Ensure indices are in range and consistent
        uint256 idx1 = address(facet).allTokensIndex(tokenId1);
        uint256 idx3 = address(facet).allTokensIndex(tokenId3);
        assertLt(idx1, 2, "allTokensIndex tokenId1 in range");
        assertLt(idx3, 2, "allTokensIndex tokenId3 in range");
    }

    function test_ShouldExportSelectors_ERC721EnumerableBurnFacet() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = bytes.concat(ERC721EnumerableBurnFacet.burn.selector);
        assertEq(selectors, expected, "exportSelectors enumerable burn facet");
    }
}

