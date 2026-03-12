// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlPausableFacet} from "src/access/AccessControl/Pausable/AccessControlPausableFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlPausableFacet_Unit_Test is Base_Test {
    AccessControlPausableFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlPausableFacet();
        vm.label(address(facet), "AccessControlPausableFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            AccessControlPausableFacet.isRolePaused.selector,
            AccessControlPausableFacet.pauseRole.selector,
            AccessControlPausableFacet.unpauseRole.selector,
            AccessControlPausableFacet.requireRoleNotPaused.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

