// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {OwnerTwoStepDataFacet} from "src/access/Owner/TwoSteps/Data/OwnerTwoStepDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract ExportSelectors_OwnerTwoStepDataFacet_Unit_Test is Base_Test {
    OwnerTwoStepDataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new OwnerTwoStepDataFacet();
        vm.label(address(facet), "OwnerTwoStepDataFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerTwoStepDataFacet.pendingOwner.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

