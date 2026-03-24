// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909ApproveFacet} from "src/token/ERC6909/Approve/ERC6909ApproveFacet.sol";

import {ERC6909_Test_Base} from "test/unit/token/ERC6909/ERC6909TestBase.sol";

abstract contract ERC6909ApproveFacet_Base_Test is ERC6909_Test_Base {
    ERC6909ApproveFacet internal facet;

    function setUp() public virtual override {
        ERC6909_Test_Base.setUp();
        facet = new ERC6909ApproveFacet();
        vm.label(address(facet), "ERC6909ApproveFacet");
    }
}
