// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721TransferFacet} from "src/token/ERC721/Transfer/ERC721TransferFacet.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

abstract contract ERC721TransferFacet_Base_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721TransferFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721TransferFacet();
        vm.label(address(facet), "ERC721TransferFacet");
    }

    function _mint(address to, uint256 tokenId) internal {
        address(facet).mint(to, tokenId);
    }
}

