// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlRevokeFacet} from "src/access/AccessControl/Revoke/AccessControlRevokeFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlRevokeFacet_Unit_Test is Base_Test {
    AccessControlRevokeFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlRevokeFacet();
        vm.label(address(facet), "AccessControlRevokeFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlRevokeFacet.revokeRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

