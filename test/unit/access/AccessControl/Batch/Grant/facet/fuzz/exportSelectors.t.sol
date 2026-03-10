// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {AccessControlGrantBatchFacet} from "src/access/AccessControl/Batch/Grant/AccessControlGrantBatchFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract ExportSelectors_AccessControlGrantBatchFacet_Unit_Test is Base_Test {
    AccessControlGrantBatchFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new AccessControlGrantBatchFacet();
        vm.label(address(facet), "AccessControlGrantBatchFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlGrantBatchFacet.grantRoleBatch.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

