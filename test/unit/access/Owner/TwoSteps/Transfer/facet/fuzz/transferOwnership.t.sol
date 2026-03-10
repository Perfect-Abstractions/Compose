// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTwoStepTransfer_Base_Test} from "test/unit/access/Owner/TwoSteps/Transfer/OwnerTwoStepTransferBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTwoStepTransferFacet} from "src/access/Owner/TwoSteps/Transfer/OwnerTwoStepTransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract TransferOwnership_OwnerTwoStepTransferFacet_Fuzz_Unit_Test is OwnerTwoStepTransfer_Base_Test {
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    OwnerTwoStepTransferFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new OwnerTwoStepTransferFacet();
        vm.label(address(facet), "OwnerTwoStepTransferFacet");
        seedOwner(address(facet), users.admin);
    }

    function testFuzz_ShouldSetPendingOwner_TransferOwnership_WhenCallerIsOwner(address newOwner) external {
        vm.prank(users.admin);
        facet.transferOwnership(newOwner);

        assertEq(OwnerStorageUtils.pendingOwner(address(facet)), newOwner, "pendingOwner");
        assertEq(OwnerStorageUtils.owner(address(facet)), users.admin, "owner unchanged");
    }

    function testFuzz_ShouldEmitOwnershipTransferStarted_TransferOwnership_WhenCallerIsOwner(address newOwner)
        external
    {
        vm.expectEmit(address(facet));
        emit OwnershipTransferStarted(users.admin, newOwner);

        vm.prank(users.admin);
        facet.transferOwnership(newOwner);
    }

    function testFuzz_ShouldRevert_TransferOwnership_WhenCallerIsNotOwner(address caller, address newOwner) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(OwnerTwoStepTransferFacet.OwnerUnauthorizedAccount.selector);
        facet.transferOwnership(newOwner);
    }

    function testFuzz_ShouldSetOwnerAndClearPending_AcceptOwnership_WhenCallerIsPendingOwner(address newOwner)
        external
    {
        vm.assume(newOwner != address(0));
        seedOwner(address(facet), users.admin);
        seedPendingOwner(address(facet), newOwner);

        vm.prank(newOwner);
        facet.acceptOwnership();

        assertEq(OwnerStorageUtils.owner(address(facet)), newOwner, "owner");
        assertEq(OwnerStorageUtils.pendingOwner(address(facet)), address(0), "pendingOwner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_AcceptOwnership_WhenCallerIsPendingOwner(address newOwner)
        external
    {
        vm.assume(newOwner != address(0));
        seedOwner(address(facet), users.admin);
        seedPendingOwner(address(facet), newOwner);

        vm.expectEmit(address(facet));
        emit OwnershipTransferred(users.admin, newOwner);

        vm.prank(newOwner);
        facet.acceptOwnership();
    }

    function testFuzz_ShouldRevert_AcceptOwnership_WhenCallerIsNotPendingOwner(address pending, address caller)
        external
    {
        vm.assume(pending != address(0));
        vm.assume(caller != pending);
        seedOwner(address(facet), users.admin);
        seedPendingOwner(address(facet), pending);

        vm.prank(caller);
        vm.expectRevert(OwnerTwoStepTransferFacet.OwnerUnauthorizedAccount.selector);
        facet.acceptOwnership();
    }

    function testFuzz_ShouldRevert_AcceptOwnership_WhenNoPendingTransfer(address caller) external {
        vm.assume(caller != address(0));
        seedOwner(address(facet), users.admin);
        /* no pending owner set */

        vm.prank(caller);
        vm.expectRevert(OwnerTwoStepTransferFacet.OwnerUnauthorizedAccount.selector);
        facet.acceptOwnership();
    }

    function testFuzz_ShouldOverwritePendingOwner_TransferOwnership_WhenCalledAgainByOwner(
        address firstPending,
        address secondPending
    )
        external
    {
        vm.assume(firstPending != address(0));
        vm.assume(secondPending != address(0));
        vm.assume(secondPending != firstPending);

        vm.prank(users.admin);
        facet.transferOwnership(firstPending);
        assertEq(OwnerStorageUtils.pendingOwner(address(facet)), firstPending, "pending after first");

        vm.expectEmit(address(facet));
        emit OwnershipTransferStarted(users.admin, secondPending);
        vm.prank(users.admin);
        facet.transferOwnership(secondPending);

        assertEq(OwnerStorageUtils.pendingOwner(address(facet)), secondPending, "pending overwritten");
        assertEq(OwnerStorageUtils.owner(address(facet)), users.admin, "owner unchanged");
    }
}
