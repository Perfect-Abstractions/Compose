// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721DataFacet_Base_Test} from "../ERC721DataFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {ERC721DataFacet} from "src/token/ERC721/Data/ERC721DataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract OwnerOf_ERC721DataFacet_Fuzz_Unit_Test is ERC721DataFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_TokenDoesNotExist(uint256 tokenId) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721DataFacet.ERC721NonexistentToken.selector, tokenId));
        facet.ownerOf(tokenId);
    }

    function testFuzz_OwnerOf(address owner, uint256 tokenId) external whenTokenExists {
        vm.assume(owner != ADDRESS_ZERO);

        address(facet).setOwnerOf(tokenId, owner);

        assertEq(facet.ownerOf(tokenId), owner, "ownerOf(tokenId)");
    }
}
