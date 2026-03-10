// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155ApproveFacet} from "src/token/ERC1155/Approve/ERC1155ApproveFacet.sol";

contract ERC1155ApproveFacet_Base_Test is Base_Test {
    ERC1155ApproveFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC1155ApproveFacet();
        vm.label(address(facet), "ERC1155ApproveFacet");
    }
}
