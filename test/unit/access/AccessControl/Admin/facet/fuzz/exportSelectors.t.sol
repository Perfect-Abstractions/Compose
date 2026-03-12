// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlAdminFacet} from "src/access/AccessControl/Admin/AccessControlAdminFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlAdminFacet_Unit_Test is Base_Test {
    AccessControlAdminFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlAdminFacet();
        vm.label(address(facet), "AccessControlAdminFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlAdminFacet.setRoleAdmin.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

