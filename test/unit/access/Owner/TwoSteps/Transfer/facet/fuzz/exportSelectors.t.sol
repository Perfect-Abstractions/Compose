// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {OwnerTwoStepTransferFacet} from "src/access/Owner/TwoSteps/Transfer/OwnerTwoStepTransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract ExportSelectors_OwnerTwoStepTransferFacet_Unit_Test is Base_Test {
    OwnerTwoStepTransferFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new OwnerTwoStepTransferFacet();
        vm.label(address(facet), "OwnerTwoStepTransferFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            OwnerTwoStepTransferFacet.transferOwnership.selector,
            OwnerTwoStepTransferFacet.acceptOwnership.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

