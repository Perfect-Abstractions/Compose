// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721MetadataFacet} from "src/token/ERC721/Metadata/ERC721MetadataFacet.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

contract ERC721MetadataFacetHarness is ERC721MetadataFacet {
    function setNameAndSymbol(string memory newName, string memory newSymbol) external {
        ERC721MetadataStorage storage s = getStorage();
        s.name = newName;
        s.symbol = newSymbol;
    }

    function setBaseURI(string memory newBaseURI) external {
        ERC721MetadataStorage storage s = getStorage();
        s.baseURI = newBaseURI;
    }
}

abstract contract ERC721MetadataFacet_Base_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721MetadataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721MetadataFacetHarness();
        vm.label(address(facet), "ERC721MetadataFacet");
    }

    function _mint(address to, uint256 tokenId) internal {
        address(facet).mint(to, tokenId);
    }

    function _setBaseURI(string memory baseURI) internal {
        ERC721MetadataFacetHarness(address(facet)).setBaseURI(baseURI);
    }
}


