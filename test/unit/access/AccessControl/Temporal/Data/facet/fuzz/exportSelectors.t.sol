// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlTemporalDataFacet} from "src/access/AccessControl/Temporal/Data/AccessControlTemporalDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlTemporalDataFacet_Unit_Test is Base_Test {
    AccessControlTemporalDataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlTemporalDataFacet();
        vm.label(address(facet), "AccessControlTemporalDataFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            AccessControlTemporalDataFacet.getRoleExpiry.selector,
            AccessControlTemporalDataFacet.isRoleExpired.selector,
            AccessControlTemporalDataFacet.requireValidRole.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

