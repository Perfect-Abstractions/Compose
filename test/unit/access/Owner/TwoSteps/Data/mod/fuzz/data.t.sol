// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTwoStepData_Base_Test} from "test/unit/access/Owner/TwoSteps/Data/OwnerTwoStepDataBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTwoStepModHarness} from "test/harnesses/access/Owner/OwnerTwoStepModHarness.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract Data_OwnerTwoStepMod_Fuzz_Unit_Test is OwnerTwoStepData_Base_Test {
    OwnerTwoStepModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new OwnerTwoStepModHarness();
        vm.label(address(harness), "OwnerTwoStepModHarness");
    }

    function testFuzz_ShouldReturnStoredPendingOwner_PendingOwner_WhenPendingOwnerHasBeenSet(address pendingOwner_)
        external
    {
        seedPendingOwner(address(harness), pendingOwner_);

        assertEq(harness.pendingOwner(), pendingOwner_, "pendingOwner");
    }

    function testFuzz_ShouldReturnZero_PendingOwner_WhenNoPendingOwnerHasBeenSet() external view {
        assertEq(harness.pendingOwner(), address(0), "pendingOwner");
    }
}
