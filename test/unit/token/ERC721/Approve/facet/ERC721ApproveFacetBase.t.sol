// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721ApproveFacet} from "src/token/ERC721/Approve/ERC721ApproveFacet.sol";

contract ERC721ApproveFacet_Base_Test is Base_Test {
    ERC721ApproveFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721ApproveFacet();
        vm.label(address(facet), "ERC721ApproveFacet");
    }
}
