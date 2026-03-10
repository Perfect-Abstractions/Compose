// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlRevokeBatchFacet} from "src/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlRevokeBatchFacet_Unit_Test is Base_Test {
    AccessControlRevokeBatchFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlRevokeBatchFacet();
        vm.label(address(facet), "AccessControlRevokeBatchFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlRevokeBatchFacet.revokeRoleBatch.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

