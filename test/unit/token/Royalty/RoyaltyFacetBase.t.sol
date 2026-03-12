// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {RoyaltyFacetHarness} from "test/utils/harnesses/token/Royalty/RoyaltyFacetHarness.sol";

abstract contract RoyaltyFacet_Base_Test is Base_Test {
    RoyaltyFacetHarness internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new RoyaltyFacetHarness();
        vm.label(address(facet), "RoyaltyFacetHarness");
    }
}
