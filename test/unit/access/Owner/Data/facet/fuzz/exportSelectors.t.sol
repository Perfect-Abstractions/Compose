// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {OwnerDataFacet} from "src/access/Owner/Data/OwnerDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract ExportSelectors_OwnerDataFacet_Unit_Test is Base_Test {
    OwnerDataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new OwnerDataFacet();
        vm.label(address(facet), "OwnerDataFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerDataFacet.owner.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

