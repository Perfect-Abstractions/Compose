// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlDataFacet} from "src/access/AccessControl/Data/AccessControlDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlDataFacet_Unit_Test is Base_Test {
    AccessControlDataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlDataFacet();
        vm.label(address(facet), "AccessControlDataFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            AccessControlDataFacet.hasRole.selector,
            AccessControlDataFacet.requireRole.selector,
            AccessControlDataFacet.getRoleAdmin.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

