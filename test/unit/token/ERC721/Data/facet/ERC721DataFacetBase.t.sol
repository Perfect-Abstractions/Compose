// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721DataFacet} from "src/token/ERC721/Data/ERC721DataFacet.sol";

contract ERC721DataFacet_Base_Test is Base_Test {
    ERC721DataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721DataFacet();
        vm.label(address(facet), "ERC721DataFacet");
    }
}
