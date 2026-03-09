// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTwoStepData_Base_Test} from "test/unit/access/Owner/TwoSteps/Data/OwnerTwoStepDataBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTwoStepDataFacet} from "src/access/Owner/TwoSteps/Data/OwnerTwoStepDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract Data_OwnerTwoStepDataFacet_Fuzz_Unit_Test is OwnerTwoStepData_Base_Test {
    OwnerTwoStepDataFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new OwnerTwoStepDataFacet();
        vm.label(address(facet), "OwnerTwoStepDataFacet");
    }

    function testFuzz_ShouldReturnStoredPendingOwner_PendingOwner_WhenPendingOwnerHasBeenSet(address pendingOwner_)
        external
    {
        seedPendingOwner(address(facet), pendingOwner_);

        assertEq(facet.pendingOwner(), pendingOwner_, "pendingOwner");
    }

    function testFuzz_ShouldReturnZero_PendingOwner_WhenNoPendingOwnerHasBeenSet() external view {
        assertEq(facet.pendingOwner(), address(0), "pendingOwner");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerTwoStepDataFacet.pendingOwner.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
