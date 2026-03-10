// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTwoStepRenounce_Base_Test} from "test/unit/access/Owner/TwoSteps/Renounce/OwnerTwoStepRenounceBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTwoStepModHarness} from "test/utils/harnesses/access/Owner/OwnerTwoStepModHarness.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract RenounceOwnership_OwnerTwoStepMod_Fuzz_Unit_Test is OwnerTwoStepRenounce_Base_Test {
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    OwnerTwoStepModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new OwnerTwoStepModHarness();
        vm.label(address(harness), "OwnerTwoStepModHarness");
        seedOwner(address(harness), users.admin);
    }

    function testFuzz_ShouldSetOwnerAndPendingToZero_RenounceOwnership_WhenCallerIsOwner() external {
        seedPendingOwner(address(harness), users.bob);

        vm.prank(users.admin);
        harness.renounceOwnership();

        assertEq(OwnerStorageUtils.owner(address(harness)), address(0), "owner");
        assertEq(OwnerStorageUtils.pendingOwner(address(harness)), address(0), "pendingOwner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_RenounceOwnership_WhenCallerIsOwner() external {
        vm.expectEmit(address(harness));
        emit OwnershipTransferred(users.admin, address(0));

        vm.prank(users.admin);
        harness.renounceOwnership();
    }

    function testFuzz_ShouldRevert_RenounceOwnership_WhenCallerIsNotOwner(address caller) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.renounceOwnership();
    }
}
