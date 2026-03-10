// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTwoStepTransfer_Base_Test} from "test/unit/access/Owner/TwoSteps/Transfer/OwnerTwoStepTransferBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTwoStepModHarness} from "test/utils/harnesses/access/Owner/OwnerTwoStepModHarness.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract TransferOwnership_OwnerTwoStepMod_Fuzz_Unit_Test is OwnerTwoStepTransfer_Base_Test {
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    OwnerTwoStepModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new OwnerTwoStepModHarness();
        vm.label(address(harness), "OwnerTwoStepModHarness");
        seedOwner(address(harness), users.admin);
    }

    function testFuzz_ShouldSetPendingOwner_TransferOwnership_WhenCallerIsOwner(address newOwner) external {
        vm.prank(users.admin);
        harness.transferOwnership(newOwner);

        assertEq(OwnerStorageUtils.pendingOwner(address(harness)), newOwner, "pendingOwner");
        assertEq(harness.owner(), users.admin, "owner unchanged");
    }

    function testFuzz_ShouldEmitOwnershipTransferStarted_TransferOwnership_WhenCallerIsOwner(address newOwner)
        external
    {
        vm.expectEmit(address(harness));
        emit OwnershipTransferStarted(users.admin, newOwner);

        vm.prank(users.admin);
        harness.transferOwnership(newOwner);
    }

    function testFuzz_ShouldRevert_TransferOwnership_WhenCallerIsNotOwner(address caller, address newOwner) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.transferOwnership(newOwner);
    }

    function testFuzz_ShouldSetOwnerAndClearPending_AcceptOwnership_WhenCallerIsPendingOwner(address newOwner)
        external
    {
        vm.assume(newOwner != address(0));
        seedOwner(address(harness), users.admin);
        seedPendingOwner(address(harness), newOwner);

        vm.prank(newOwner);
        harness.acceptOwnership();

        assertEq(harness.owner(), newOwner, "owner");
        assertEq(OwnerStorageUtils.pendingOwner(address(harness)), address(0), "pendingOwner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_AcceptOwnership_WhenCallerIsPendingOwner(address newOwner)
        external
    {
        vm.assume(newOwner != address(0));
        seedOwner(address(harness), users.admin);
        seedPendingOwner(address(harness), newOwner);

        vm.expectEmit(address(harness));
        emit OwnershipTransferred(users.admin, newOwner);

        vm.prank(newOwner);
        harness.acceptOwnership();
    }

    function testFuzz_ShouldRevert_AcceptOwnership_WhenCallerIsNotPendingOwner(address pending, address caller)
        external
    {
        vm.assume(pending != address(0));
        vm.assume(caller != pending);
        seedOwner(address(harness), users.admin);
        seedPendingOwner(address(harness), pending);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.acceptOwnership();
    }

    function testFuzz_ShouldRevert_AcceptOwnership_WhenNoPendingTransfer(address caller) external {
        vm.assume(caller != address(0));
        seedOwner(address(harness), users.admin);
        /* no pending owner set */

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.acceptOwnership();
    }

    function testFuzz_ShouldOverwritePendingOwner_TransferOwnership_WhenCalledAgainByOwner(
        address firstPending,
        address secondPending
    ) external {
        vm.assume(firstPending != address(0));
        vm.assume(secondPending != address(0));
        vm.assume(secondPending != firstPending);

        vm.prank(users.admin);
        harness.transferOwnership(firstPending);
        assertEq(OwnerStorageUtils.pendingOwner(address(harness)), firstPending, "pending after first");

        vm.expectEmit(address(harness));
        emit OwnershipTransferStarted(users.admin, secondPending);
        vm.prank(users.admin);
        harness.transferOwnership(secondPending);

        assertEq(OwnerStorageUtils.pendingOwner(address(harness)), secondPending, "pending overwritten");
        assertEq(harness.owner(), users.admin, "owner unchanged");
    }
}
