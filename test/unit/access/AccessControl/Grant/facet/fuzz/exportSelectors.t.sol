// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlGrantFacet} from "src/access/AccessControl/Grant/AccessControlGrantFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlGrantFacet_Unit_Test is Base_Test {
    AccessControlGrantFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlGrantFacet();
        vm.label(address(facet), "AccessControlGrantFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlGrantFacet.grantRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

