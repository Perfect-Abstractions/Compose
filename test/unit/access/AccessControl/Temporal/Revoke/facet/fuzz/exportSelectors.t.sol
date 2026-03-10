// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {
    AccessControlTemporalRevokeFacet
} from "src/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlTemporalRevokeFacet_Unit_Test is Base_Test {
    AccessControlTemporalRevokeFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlTemporalRevokeFacet();
        vm.label(address(facet), "AccessControlTemporalRevokeFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlTemporalRevokeFacet.revokeTemporalRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

