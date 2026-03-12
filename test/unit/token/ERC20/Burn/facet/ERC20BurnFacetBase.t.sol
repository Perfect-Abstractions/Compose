// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20BurnFacet} from "src/token/ERC20/Burn/ERC20BurnFacet.sol";

contract ERC20BurnFacet_Base_Test is Base_Test {
    ERC20BurnFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20BurnFacet();
        vm.label(address(facet), "ERC20BurnFacet");
    }
}
