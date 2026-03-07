// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721TransferFacet_Base_Test} from "../ERC721TransferFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {ERC721TransferFacet} from "src/token/ERC721/Transfer/ERC721TransferFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract TransferFrom_ERC721TransferFacet_Fuzz_Unit_Test is ERC721TransferFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_TokenDoesNotExist(address from, address to, uint256 tokenId) external {
        vm.assume(to != ADDRESS_ZERO);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721NonexistentToken.selector, tokenId));
        facet.transferFrom(from, to, tokenId);
    }

    function testFuzz_ShouldRevert_FromNotOwner(address from, address to, uint256 tokenId)
        external
        whenTokenExists
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(from != users.alice);

        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721IncorrectOwner.selector, from, tokenId, users.alice)
        );
        facet.transferFrom(from, to, tokenId);
    }

    function testFuzz_ShouldRevert_ToIsZeroAddress(uint256 tokenId) external whenTokenExists whenFromIsOwner {
        address(facet).mint(users.alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721TransferFacet.ERC721InvalidReceiver.selector, ADDRESS_ZERO));
        facet.transferFrom(users.alice, ADDRESS_ZERO, tokenId);
    }

    function testFuzz_ShouldRevert_CallerNotAuthorized(address owner, address to, uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);
        vm.assume(to != ADDRESS_ZERO);

        address(facet).mint(owner, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721TransferFacet.ERC721InsufficientApproval.selector, users.alice, tokenId)
        );
        facet.transferFrom(owner, to, tokenId);
    }

    function testFuzz_TransferFrom_CallerIsOwner(address to, uint256 tokenId, address approved)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != users.alice);

        address(facet).mint(users.alice, tokenId);
        address(facet).setApproved(tokenId, approved);

        uint256 senderBalanceBefore = address(facet).balanceOf(users.alice);
        uint256 receiverBalanceBefore = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(users.alice, to, tokenId);
        facet.transferFrom(users.alice, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(users.alice), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), receiverBalanceBefore + 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    function testFuzz_TransferFrom_CallerIsApprovedOperator(address owner, address to, uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != owner);

        address(facet).mint(owner, tokenId);
        address(facet).setApprovalForAll(owner, users.alice, true);

        uint256 senderBalanceBefore = address(facet).balanceOf(owner);
        uint256 receiverBalanceBefore = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(owner), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), receiverBalanceBefore + 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }

    function testFuzz_TransferFrom_CallerIsTokenApproved(address owner, address to, uint256 tokenId)
        external
        whenTokenExists
        whenFromIsOwner
        whenToNotZeroAddress
        whenCallerIsAuthorized
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != owner);

        address(facet).mint(owner, tokenId);
        address(facet).setApproved(tokenId, users.alice);

        uint256 senderBalanceBefore = address(facet).balanceOf(owner);
        uint256 receiverBalanceBefore = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC721TransferFacet.Transfer(owner, to, tokenId);
        facet.transferFrom(owner, to, tokenId);

        assertEq(address(facet).ownerOf(tokenId), to, "ownerOf(tokenId)");
        assertEq(address(facet).balanceOf(owner), senderBalanceBefore - 1, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), receiverBalanceBefore + 1, "balanceOf(to)");
        assertEq(address(facet).getApproved(tokenId), ADDRESS_ZERO, "getApproved(tokenId)");
    }
}
