/**
 *  SPDX-License-Identifier: MIT
 */
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {OwnerTwoStepsFacet} from "../../../src/access/OwnerTwoSteps/OwnerTwoSteps.sol";
import {OwnerTwoStepsFacetHarness} from "./harnesses/OwnerTwoStepsFacetHarness.sol";

contract OwnerTwoStepsFacetTest is Test {
    OwnerTwoStepsFacetHarness public ownerTwoSteps;

    address INITIAL_OWNER = makeAddr("owner");
    address NEW_OWNER = makeAddr("newOwner");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address ZERO_ADDRESS = address(0);

    /**
     * Events
     */
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    function setUp() public {
        ownerTwoSteps = new OwnerTwoStepsFacetHarness();
        ownerTwoSteps.initialize(INITIAL_OWNER);
    }

    /**
     * ============================================
     * Ownership Getter Tests
     * ============================================
     */

    function test_Owner_ReturnsCorrectInitialOwner() public view {
        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
    }

    function test_PendingOwner_InitiallyZero() public view {
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    /**
     * ============================================
     * Transfer Ownership Initiation Tests
     * ============================================
     */

    function test_TransferOwnership_OnlyOwnerCanInitiate() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), NEW_OWNER);
    }

    function test_TransferOwnership_EmitsOwnershipTransferStartedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferStarted(INITIAL_OWNER, NEW_OWNER);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);
    }

    function test_TransferOwnership_CanTransferToZeroAddress() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ZERO_ADDRESS);

        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function test_TransferOwnership_CanUpdatePendingOwner() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ALICE);
        assertEq(ownerTwoSteps.pendingOwner(), ALICE);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(BOB);
        assertEq(ownerTwoSteps.pendingOwner(), BOB);
    }

    function test_TransferOwnership_CanCancelBySettingToZero() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), NEW_OWNER);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ZERO_ADDRESS);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function test_RevertWhen_TransferOwnership_CalledByNonOwner() public {
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.transferOwnership(ALICE);
    }

    function test_RevertWhen_TransferOwnership_CalledByPendingOwner() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(NEW_OWNER);
        ownerTwoSteps.transferOwnership(ALICE);
    }

    /**
     * ============================================
     * Accept Ownership Tests
     * ============================================
     */

    function test_AcceptOwnership_CompletesTransfer() public {
        /**
         * Initiate transfer
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        /**
         * Accept ownership
         */
        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();

        /**
         * Verify ownership transferred
         */
        assertEq(ownerTwoSteps.owner(), NEW_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function test_AcceptOwnership_EmitsOwnershipTransferredEvent() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, NEW_OWNER);

        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();
    }

    function test_AcceptOwnership_ClearsPendingOwner() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();

        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function test_RevertWhen_AcceptOwnership_CalledByNonPendingOwner() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.acceptOwnership();
    }

    function test_RevertWhen_AcceptOwnership_CalledByCurrentOwner() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.acceptOwnership();
    }

    function test_RevertWhen_AcceptOwnership_NoPendingOwner() public {
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.acceptOwnership();
    }

    /**
     * ============================================
     * Renounce Ownership Tests (via Zero Address)
     * ============================================
     */

    function test_RenounceOwnership_TwoStep() public {
        /**
         * Initiate renouncement
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ZERO_ADDRESS);

        /**
         * Owner should still be the same
         */
        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);

        /**
         * Note: Zero address cannot accept ownership (no private key)
         * This effectively cancels the renouncement unless there's another mechanism
         */
    }

    /**
     * ============================================
     * Sequential Transfer Tests
     * ============================================
     */

    function test_SequentialTransfers() public {
        /**
         * First transfer
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ALICE);

        vm.prank(ALICE);
        ownerTwoSteps.acceptOwnership();
        assertEq(ownerTwoSteps.owner(), ALICE);

        /**
         * Second transfer
         */
        vm.prank(ALICE);
        ownerTwoSteps.transferOwnership(BOB);

        vm.prank(BOB);
        ownerTwoSteps.acceptOwnership();
        assertEq(ownerTwoSteps.owner(), BOB);

        /**
         * Third transfer back to initial
         */
        vm.prank(BOB);
        ownerTwoSteps.transferOwnership(INITIAL_OWNER);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.acceptOwnership();
        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
    }

    function test_TransferToSelf() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(INITIAL_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), INITIAL_OWNER);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.acceptOwnership();
        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
    }

    /**
     * ============================================
     * Edge Cases
     * ============================================
     */

    function test_MultiplePendingChanges_OnlyLastOneMatters() public {
        vm.startPrank(INITIAL_OWNER);

        ownerTwoSteps.transferOwnership(ALICE);
        assertEq(ownerTwoSteps.pendingOwner(), ALICE);

        ownerTwoSteps.transferOwnership(BOB);
        assertEq(ownerTwoSteps.pendingOwner(), BOB);

        ownerTwoSteps.transferOwnership(NEW_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), NEW_OWNER);

        vm.stopPrank();

        /**
         * Alice and Bob cannot accept
         */
        vm.prank(ALICE);
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        ownerTwoSteps.acceptOwnership();

        vm.prank(BOB);
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        ownerTwoSteps.acceptOwnership();

        /**
         * Only NEW_OWNER can accept
         */
        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();
        assertEq(ownerTwoSteps.owner(), NEW_OWNER);
    }

    /**
     * ============================================
     * Fuzz Tests
     * ============================================
     */

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(newOwner);

        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), newOwner);
    }

    function testFuzz_AcceptOwnership(address newOwner) public {
        vm.assume(newOwner != address(0)); // Zero address can't execute transactions

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(newOwner);

        vm.prank(newOwner);
        ownerTwoSteps.acceptOwnership();

        assertEq(ownerTwoSteps.owner(), newOwner);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function testFuzz_RevertWhen_UnauthorizedTransfer(address caller, address target) public {
        vm.assume(caller != INITIAL_OWNER);

        vm.prank(caller);
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        ownerTwoSteps.transferOwnership(target);
    }

    function testFuzz_RevertWhen_UnauthorizedAccept(address caller) public {
        vm.assume(caller != NEW_OWNER);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        vm.prank(caller);
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        ownerTwoSteps.acceptOwnership();
    }

    /**
     * ============================================
     * Direct Renouncement Tests (renounceOwnership)
     * ============================================
     */

    function test_RenounceOwnership_DirectlyRenounces() public {
        /**
         * Call renounceOwnership directly
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        /**
         * Verify both owner and pendingOwner are zero
         */
        assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function test_RenounceOwnership_OnlyOwnerCanCall() public {
        /**
         * Only the owner should be able to renounce
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
    }

    function test_RenounceOwnership_EmitsOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ZERO_ADDRESS);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();
    }

    function test_RenounceOwnership_ClearsPendingOwner() public {
        /**
         * Set a pending owner first
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), NEW_OWNER);

        /**
         * Renounce should clear pending owner
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    function test_RevertWhen_RenounceOwnership_CalledByNonOwner() public {
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.renounceOwnership();

        /**
         * Owner should remain unchanged
         */
        assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
    }

    function test_RevertWhen_RenounceOwnership_CalledByPendingOwner() public {
        /**
         * Set pending owner
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        /**
         * Pending owner cannot renounce
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(NEW_OWNER);
        ownerTwoSteps.renounceOwnership();
    }

    function test_RenounceOwnership_PreventsAllFutureTransfers() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        /**
         * Any address trying to transfer should fail
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.transferOwnership(BOB);

        /**
         * Even the previous owner cannot transfer
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);
    }

    function test_RenounceOwnership_CannotBeReversed() public {
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        /**
         * Cannot accept ownership (no pending owner)
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.acceptOwnership();

        /**
         * Cannot renounce again
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerTwoSteps.renounceOwnership();
    }

    /**
     * ============================================
     * Storage Tests
     * ============================================
     */

    function test_StorageSlot_Consistency() public {
        bytes32 expectedSlot = keccak256("compose.owner");

        /**
         * Set pending owner
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);

        /**
         * Accept ownership
         */
        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();

        /**
         * Read directly from storage
         */
        bytes32 storedValue = vm.load(address(ownerTwoSteps), expectedSlot);
        address storedOwner = address(uint160(uint256(storedValue)));

        assertEq(storedOwner, NEW_OWNER);
        assertEq(ownerTwoSteps.owner(), NEW_OWNER);
    }

    function test_StorageSlot_PendingOwner() public {
        bytes32 expectedSlot = keccak256("compose.owner");
        bytes32 pendingSlot = bytes32(uint256(expectedSlot) + 1);

        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ALICE);

        /**
         * Read pending owner from storage
         */
        bytes32 pendingValue = vm.load(address(ownerTwoSteps), pendingSlot);
        address storedPendingOwner = address(uint160(uint256(pendingValue)));

        assertEq(storedPendingOwner, ALICE);
        assertEq(ownerTwoSteps.pendingOwner(), ALICE);
    }

    /**
     * ============================================
     * Edge Cases
     * ============================================
     */

    function test_RenounceOwnership_WithPendingTransfer() public {
        /**
         * Start a two-step transfer
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), NEW_OWNER);

        /**
         * Direct renouncement should override pending transfer
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        /**
         * Both should be zero
         */
        assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);

        /**
         * Pending owner can no longer accept
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();
    }

    function test_DirectRenounce_vs_TwoStepRenounce() public {
        /**
         * Test 1: Two-step renounce (can be cancelled)
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(ZERO_ADDRESS);

        /**
         * Can still change mind
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(NEW_OWNER);
        assertEq(ownerTwoSteps.pendingOwner(), NEW_OWNER);

        /**
         * Reset for test 2
         */
        vm.prank(NEW_OWNER);
        ownerTwoSteps.acceptOwnership();

        /**
         * Test 2: Direct renounce (immediate and irreversible)
         */
        vm.prank(NEW_OWNER);
        ownerTwoSteps.renounceOwnership();
        assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);
    }

    /**
     * ============================================
     * Additional Fuzz Tests
     * ============================================
     */

    function testFuzz_RenounceOwnership_OnlyOwner(address caller) public {
        if (caller == INITIAL_OWNER) {
            vm.prank(caller);
            ownerTwoSteps.renounceOwnership();
            assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
        } else {
            vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
            vm.prank(caller);
            ownerTwoSteps.renounceOwnership();
            assertEq(ownerTwoSteps.owner(), INITIAL_OWNER);
        }
    }

    function testFuzz_StateAfterRenounce(address caller, address target) public {
        /**
         * Renounce ownership
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        /**
         * Zero address can't make calls anyway
         */
        if (caller != ZERO_ADDRESS) {
            /**
             * No matter who calls or with what target, transfers should fail
             */
            vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
            vm.prank(caller);
            ownerTwoSteps.transferOwnership(target);

            /**
             * Acceptance should also fail
             */
            vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
            vm.prank(caller);
            ownerTwoSteps.acceptOwnership();

            /**
             * Renounce should also fail
             */
            vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
            vm.prank(caller);
            ownerTwoSteps.renounceOwnership();
        }
    }

    function testFuzz_RenounceWithPendingOwner(address pendingOwner) public {
        vm.assume(pendingOwner != address(0));

        /**
         * Set pending owner
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.transferOwnership(pendingOwner);

        /**
         * Renounce clears everything
         */
        vm.prank(INITIAL_OWNER);
        ownerTwoSteps.renounceOwnership();

        assertEq(ownerTwoSteps.owner(), ZERO_ADDRESS);
        assertEq(ownerTwoSteps.pendingOwner(), ZERO_ADDRESS);

        /**
         * Pending owner can no longer accept
         */
        vm.expectRevert(OwnerTwoStepsFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(pendingOwner);
        ownerTwoSteps.acceptOwnership();
    }
}
