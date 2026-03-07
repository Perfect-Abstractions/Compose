// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {ERC721BurnFacet} from "src/token/ERC721/Burn/ERC721BurnFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract BurnERC721_ERC721BurnFacet_Fuzz_Unit_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721BurnFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721BurnFacet();
        vm.label(address(facet), "ERC721BurnFacet");
    }

    function testFuzz_ShouldRevert_TokenDoesNotExist(uint256 tokenId) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721BurnFacet.ERC721NonexistentToken.selector, tokenId));
        facet.burnERC721(tokenId);
    }

    function testFuzz_ShouldRevert_CallerNotAuthorized(address owner, uint256 tokenId) external whenTokenExists {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);

        address(facet).mint(owner, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721BurnFacet.ERC721InsufficientApproval.selector, users.alice, tokenId)
        );
        facet.burnERC721(tokenId);
    }

    function testFuzz_Burn_CallerIsOwner(uint256 tokenId, address approved)
        external
        whenTokenExists
        whenCallerIsAuthorized
    {
        address(facet).mint(users.alice, tokenId);
        address(facet).setApproved(tokenId, approved);

        uint256 balanceBefore = address(facet).balanceOf(users.alice);

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(users.alice, ADDRESS_ZERO, tokenId);
        facet.burnERC721(tokenId);

        assertEq(address(facet).ownerOf(tokenId), ADDRESS_ZERO, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(users.alice), balanceBefore - 1, "balanceOf(owner)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    function testFuzz_Burn_CallerIsApprovedOperator(address owner, uint256 tokenId, address approved)
        external
        whenTokenExists
        whenCallerIsAuthorized
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);

        address(facet).mint(owner, tokenId);
        address(facet).setApprovalForAll(owner, users.alice, true);
        address(facet).setApproved(tokenId, approved);

        uint256 balanceBefore = address(facet).balanceOf(owner);

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, ADDRESS_ZERO, tokenId);
        facet.burnERC721(tokenId);

        assertEq(address(facet).ownerOf(tokenId), ADDRESS_ZERO, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(owner), balanceBefore - 1, "balanceOf(owner)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    function testFuzz_Burn_CallerIsTokenApproved(address owner, uint256 tokenId)
        external
        whenTokenExists
        whenCallerIsAuthorized
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);

        address(facet).mint(owner, tokenId);
        address(facet).setApproved(tokenId, users.alice);

        uint256 balanceBefore = address(facet).balanceOf(owner);

        vm.expectEmit(address(facet));
        emit ERC721BurnFacet.Transfer(owner, ADDRESS_ZERO, tokenId);
        facet.burnERC721(tokenId);

        assertEq(address(facet).ownerOf(tokenId), ADDRESS_ZERO, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(owner), balanceBefore - 1, "balanceOf(owner)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }
}
