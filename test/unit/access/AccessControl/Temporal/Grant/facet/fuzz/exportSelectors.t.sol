// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {
    AccessControlTemporalGrantFacet
} from "src/access/AccessControl/Temporal/Grant/AccessControlTemporalGrantFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlTemporalGrantFacet_Unit_Test is Base_Test {
    AccessControlTemporalGrantFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlTemporalGrantFacet();
        vm.label(address(facet), "AccessControlTemporalGrantFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlTemporalGrantFacet.grantRoleWithExpiry.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

