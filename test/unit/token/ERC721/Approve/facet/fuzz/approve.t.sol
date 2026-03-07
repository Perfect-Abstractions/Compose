// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721ApproveFacet_Base_Test} from "../ERC721ApproveFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {ERC721ApproveFacet} from "src/token/ERC721/Approve/ERC721ApproveFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract Approve_ERC721ApproveFacet_Fuzz_Unit_Test is ERC721ApproveFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_TokenDoesNotExist(address to, uint256 tokenId) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721ApproveFacet.ERC721NonexistentToken.selector, tokenId));
        facet.approve(to, tokenId);
    }

    function testFuzz_ShouldRevert_CallerNotOwnerAndNotOperator(address owner, address to, uint256 tokenId)
        external
        whenTokenExists
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);

        address(facet).mint(owner, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721ApproveFacet.ERC721InvalidApprover.selector, users.alice));
        facet.approve(to, tokenId);
    }

    function testFuzz_Approve_CallerIsOwner(address to, uint256 tokenId) external whenTokenExists {
        address(facet).mint(users.alice, tokenId);

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.Approval(users.alice, to, tokenId);
        facet.approve(to, tokenId);

        assertEq(address(facet).getApproved(tokenId), to, "getApproved(tokenId)");
    }

    function testFuzz_Approve_CallerIsApprovedOperator(address owner, address to, uint256 tokenId)
        external
        whenTokenExists
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(owner != users.alice);

        address(facet).mint(owner, tokenId);
        address(facet).setApprovalForAll(owner, users.alice, true);

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.Approval(owner, to, tokenId);
        facet.approve(to, tokenId);

        assertEq(address(facet).getApproved(tokenId), to, "getApproved(tokenId)");
    }
}
