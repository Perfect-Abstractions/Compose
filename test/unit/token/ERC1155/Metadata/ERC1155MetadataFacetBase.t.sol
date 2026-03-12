// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155MetadataFacet} from "src/token/ERC1155/Metadata/ERC1155MetadataFacet.sol";

contract ERC1155MetadataFacet_Base_Test is Base_Test {
    ERC1155MetadataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC1155MetadataFacet();
        vm.label(address(facet), "ERC1155MetadataFacet");
    }
}
