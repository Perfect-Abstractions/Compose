// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlRenounceFacet} from "src/access/AccessControl/Renounce/AccessControlRenounceFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlRenounceFacet_Unit_Test is Base_Test {
    AccessControlRenounceFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlRenounceFacet();
        vm.label(address(facet), "AccessControlRenounceFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlRenounceFacet.renounceRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

