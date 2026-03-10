// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721BurnFacet_Base_Test} from "test/unit/token/ERC721/Burn/ERC721BurnFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721BurnFacet} from "src/token/ERC721/Burn/ERC721BurnFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Burn_ERC721BurnFacet_Fuzz_Unit_Test is ERC721BurnFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_Burn_WhenTokenDoesNotExist(uint256 tokenId) external {
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721BurnFacet.ERC721NonexistentToken.selector, tokenId));
        facet.burn(tokenId);
    }

    function testFuzz_ShouldRevert_Burn_WhenCallerNotOwnerOrApproved(address owner, address caller, uint256 tokenId)
        external
    {
        vm.assume(owner != address(0));
        vm.assume(caller != owner);
        vm.assume(caller != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(caller);

        vm.expectRevert(abi.encodeWithSelector(ERC721BurnFacet.ERC721InsufficientApproval.selector, caller, tokenId));
        facet.burn(tokenId);
    }

    function testFuzz_ShouldBurn_WhenCallerIsOwner(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);

        vm.stopPrank();
        vm.prank(owner);

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, address(0), tokenId);
        facet.burn(tokenId);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
        vm.expectRevert(abi.encodeWithSelector(ERC721BurnFacet.ERC721NonexistentToken.selector, tokenId));
        facet.burn(tokenId);
    }

    function testFuzz_ShouldBurn_WhenCallerIsApproved(address owner, address approved, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(approved != address(0));
        vm.assume(approved != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        address(facet).setApproved(tokenId, approved);

        vm.stopPrank();
        vm.prank(approved);

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, address(0), tokenId);
        facet.burn(tokenId);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
    }

    function testFuzz_ShouldBurn_WhenCallerIsOperator(address owner, address operator, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(operator != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(facet).mint(owner, tokenId);
        address(facet).setApprovedForAll(owner, operator, true);

        vm.stopPrank();
        vm.prank(operator);

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, address(0), tokenId);
        facet.burn(tokenId);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
    }

    function testFuzz_ShouldBurnBatch_WhenAllTokensExistAndCallerAuthorized(
        address owner,
        uint256 tokenId1,
        uint256 tokenId2
    ) external {
        vm.assume(owner != address(0));
        tokenId1 = bound(tokenId1, 1, type(uint128).max);
        tokenId2 = bound(tokenId2, 2, type(uint128).max);
        vm.assume(tokenId1 != tokenId2);

        address(facet).mint(owner, tokenId1);
        address(facet).mint(owner, tokenId2);

        vm.stopPrank();
        vm.prank(owner);

        uint256[] memory ids = new uint256[](2);
        ids[0] = tokenId1;
        ids[1] = tokenId2;

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, address(0), tokenId1);
        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, address(0), tokenId2);
        facet.burnBatch(ids);

        assertEq(address(facet).balanceOf(owner), 0, "owner balance");
    }

    function testFuzz_ShouldRevert_BurnBatch_WhenAnyTokenDoesNotExist(
        address owner,
        uint256 existingTokenId,
        uint256 nonexistentTokenId
    ) external {
        vm.assume(owner != address(0));
        existingTokenId = bound(existingTokenId, 1, type(uint128).max);
        nonexistentTokenId = bound(nonexistentTokenId, 2, type(uint128).max);
        vm.assume(existingTokenId != nonexistentTokenId);

        address(facet).mint(owner, existingTokenId);

        vm.stopPrank();
        vm.prank(owner);

        uint256[] memory ids = new uint256[](2);
        ids[0] = existingTokenId;
        ids[1] = nonexistentTokenId;

        vm.expectRevert(
            abi.encodeWithSelector(ERC721BurnFacet.ERC721NonexistentToken.selector, nonexistentTokenId)
        );
        facet.burnBatch(ids);
    }

    function testFuzz_ShouldRevert_BurnBatch_WhenCallerNotOwnerOrApproved(
        address owner,
        address caller,
        uint256 tokenId1,
        uint256 tokenId2
    ) external {
        vm.assume(owner != address(0));
        vm.assume(caller != address(0));
        vm.assume(caller != owner);
        tokenId1 = bound(tokenId1, 1, type(uint128).max);
        tokenId2 = bound(tokenId2, 2, type(uint128).max);
        vm.assume(tokenId1 != tokenId2);

        address(facet).mint(owner, tokenId1);
        address(facet).mint(owner, tokenId2);

        vm.stopPrank();
        vm.prank(caller);

        uint256[] memory ids = new uint256[](2);
        ids[0] = tokenId1;
        ids[1] = tokenId2;

        vm.expectRevert(
            abi.encodeWithSelector(ERC721BurnFacet.ERC721InsufficientApproval.selector, caller, tokenId1)
        );
        facet.burnBatch(ids);
    }
}

