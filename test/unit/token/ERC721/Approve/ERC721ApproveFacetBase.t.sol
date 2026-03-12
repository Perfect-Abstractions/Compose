// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721ApproveFacet} from "src/token/ERC721/Approve/ERC721ApproveFacet.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

abstract contract ERC721ApproveFacet_Base_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721ApproveFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721ApproveFacet();
        vm.label(address(facet), "ERC721ApproveFacet");
    }

    function _mint(address to, uint256 tokenId) internal {
        address(facet).mint(to, tokenId);
    }
}

