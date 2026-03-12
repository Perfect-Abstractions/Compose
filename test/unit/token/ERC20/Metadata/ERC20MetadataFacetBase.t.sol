// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20MetadataFacet} from "src/token/ERC20/Metadata/ERC20MetadataFacet.sol";
import {ERC20MetadataModHarness} from "test/utils/harnesses/token/ERC20/ERC20MetadataModHarness.sol";

abstract contract ERC20MetadataFacet_Base_Test is Base_Test {
    ERC20MetadataModHarness internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20MetadataModHarness();
        vm.label(address(facet), "ERC20MetadataModHarness");
    }
}
