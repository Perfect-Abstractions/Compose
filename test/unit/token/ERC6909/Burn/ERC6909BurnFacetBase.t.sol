// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909BurnFacet} from "src/token/ERC6909/Burn/ERC6909BurnFacet.sol";

import {ERC6909_Test_Base} from "test/unit/token/ERC6909/ERC6909TestBase.sol";

abstract contract ERC6909BurnFacet_Base_Test is ERC6909_Test_Base {
    ERC6909BurnFacet internal facet;

    function setUp() public virtual override {
        ERC6909_Test_Base.setUp();
        facet = new ERC6909BurnFacet();
        vm.label(address(facet), "ERC6909BurnFacet");
    }
}
