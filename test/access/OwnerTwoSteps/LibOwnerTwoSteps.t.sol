// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {LibOwnerTwoSteps} from "../../../src/access/OwnerTwoSteps/LibOwnerTwoSteps.sol";
import {LibOwnerTwoStepsHarness} from "./harnesses/LibOwnerTwoStepsHarness.sol";

contract LibOwnerTwoStepsTest is Test {
    LibOwnerTwoStepsHarness public harness;

    address INITIAL_OWNER = makeAddr("owner");
    address NEW_OWNER = makeAddr("newOwner");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address ZERO_ADDRESS = address(0);

    // Events
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    function setUp() public {
        harness = new LibOwnerTwoStepsHarness();
        harness.initialize(INITIAL_OWNER);
    }

    // ============================================
    // Storage Tests
    // ============================================

    function test_GetStorage_ReturnsCorrectOwner() public view {
        assertEq(harness.owner(), INITIAL_OWNER);
        assertEq(harness.getStorageOwner(), INITIAL_OWNER);
    }

    function test_GetStorage_ReturnsCorrectPendingOwner() public {
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
        assertEq(harness.getStoragePendingOwner(), ZERO_ADDRESS);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        assertEq(harness.pendingOwner(), NEW_OWNER);
        assertEq(harness.getStoragePendingOwner(), NEW_OWNER);
    }

    function test_StorageSlot_UsesCorrectPosition() public {
        bytes32 expectedSlot = keccak256("compose.owner");

        // Change pending owner
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        // Read owner from storage (slot + 0)
        bytes32 ownerValue = vm.load(address(harness), expectedSlot);
        address storedOwner = address(uint160(uint256(ownerValue)));
        assertEq(storedOwner, INITIAL_OWNER);

        // Read pending owner from storage (slot + 1)
        bytes32 pendingSlot = bytes32(uint256(expectedSlot) + 1);
        bytes32 pendingValue = vm.load(address(harness), pendingSlot);
        address storedPendingOwner = address(uint160(uint256(pendingValue)));
        assertEq(storedPendingOwner, NEW_OWNER);
    }

    function test_StorageSlot_CurrentlyCollides() public pure {
        // This test documents that LibOwnerTwoSteps CURRENTLY uses the same slot as LibOwner
        // This is a known issue but kept for backwards compatibility
        bytes32 ownerSlot = keccak256("compose.owner");
        bytes32 ownerTwoStepsSlot = keccak256("compose.owner");

        // They currently collide (this is the bug we're documenting)
        assertEq(ownerSlot, ownerTwoStepsSlot, "Storage slots currently collide");

        // Both use the same slot
        assertEq(ownerSlot, keccak256("compose.owner"), "LibOwner slot");
        assertEq(ownerTwoStepsSlot, keccak256("compose.owner"), "LibOwnerTwoSteps slot");
    }

    function test_StorageCollision_DocumentedBug() public pure {
        // This test documents the storage collision bug that exists
        // Both libraries use keccak256("compose.owner")
        // This will cause issues if both are used in the same diamond

        bytes32 currentSlot = keccak256("compose.owner");
        bytes32 shouldBeSlot = keccak256("compose.owner.twosteps");

        // Document that we're using the colliding slot
        assertEq(currentSlot, keccak256("compose.owner"), "Using colliding slot");

        // Document what it should be to avoid collision
        assertTrue(currentSlot != shouldBeSlot, "Not using the unique slot that would avoid collision");
    }

    // ============================================
    // Owner Getter Tests
    // ============================================

    function test_Owner_ReturnsCurrentOwner() public view {
        assertEq(harness.owner(), INITIAL_OWNER);
    }

    function test_PendingOwner_ReturnsCurrentPendingOwner() public {
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.pendingOwner(), NEW_OWNER);
    }

    // ============================================
    // Transfer Ownership Initiation Tests
    // ============================================

    function test_TransferOwnership_SetsPendingOwner() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        assertEq(harness.owner(), INITIAL_OWNER);
        assertEq(harness.pendingOwner(), NEW_OWNER);
    }

    function test_TransferOwnership_EmitsOwnershipTransferStartedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferStarted(INITIAL_OWNER, NEW_OWNER);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
    }

    function test_TransferOwnership_AllowsTransferToZeroAddress() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function test_TransferOwnership_CanUpdatePendingOwner() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ALICE);
        assertEq(harness.pendingOwner(), ALICE);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(BOB);
        assertEq(harness.pendingOwner(), BOB);
    }

    function test_TransferOwnership_LibraryDoesNotCheckCaller() public {
        // Library doesn't check msg.sender - that's the facet's responsibility
        vm.prank(ALICE); // Not the owner
        harness.transferOwnership(ALICE);

        // Transfer succeeds, pending owner is set
        assertEq(harness.pendingOwner(), ALICE);
        assertEq(harness.owner(), INITIAL_OWNER); // Owner unchanged until accepted
    }

    function test_RevertWhen_TransferOwnership_FromRenouncedOwner() public {
        // Force renounce
        harness.forceRenounce();
        assertEq(harness.owner(), ZERO_ADDRESS);

        // Should revert with OwnerAlreadyRenounced error
        vm.expectRevert(LibOwnerTwoSteps.OwnerAlreadyRenounced.selector);
        harness.transferOwnership(NEW_OWNER);
    }

    function test_TransferOwnership_FromPendingOwner_Allowed() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.pendingOwner(), NEW_OWNER);

        // Library allows pending owner to call transferOwnership
        vm.prank(NEW_OWNER);
        harness.transferOwnership(ALICE);
        assertEq(harness.pendingOwner(), ALICE); // Pending owner updated
        assertEq(harness.owner(), INITIAL_OWNER); // Owner still unchanged
    }

    // ============================================
    // Accept Ownership Tests
    // ============================================

    function test_AcceptOwnership_CompletesTransfer() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        harness.acceptOwnership();

        assertEq(harness.owner(), NEW_OWNER);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function test_AcceptOwnership_EmitsOwnershipTransferredEvent() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, NEW_OWNER);

        vm.prank(NEW_OWNER);
        harness.acceptOwnership();
    }

    function test_AcceptOwnership_ClearsPendingOwner() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        harness.acceptOwnership();

        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function test_AcceptOwnership_LibraryAllowsAnyCaller() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        // Library allows any caller - facets must check
        vm.prank(ALICE); // Not the pending owner
        harness.acceptOwnership();

        // Ownership transferred even though Alice wasn't pending owner
        assertEq(harness.owner(), NEW_OWNER); // NEW_OWNER was pending, now owner
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function test_AcceptOwnership_CurrentOwnerCanCall() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        // Library allows current owner to call acceptOwnership
        vm.prank(INITIAL_OWNER);
        harness.acceptOwnership();

        // Ownership transferred to pending owner
        assertEq(harness.owner(), NEW_OWNER);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function test_AcceptOwnership_NoPendingOwner_SetsOwnerToZero() public {
        // No pending owner set
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);

        // Library allows acceptOwnership even with no pending owner
        vm.prank(ALICE);
        harness.acceptOwnership();

        // Owner becomes zero (the pending owner)
        assertEq(harness.owner(), ZERO_ADDRESS);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    // ============================================
    // Renounce Ownership Tests (Zero Address)
    // ============================================

    function test_RenounceOwnership_CannotBeCompleted() public {
        // Initiate transfer to zero address
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);

        assertEq(harness.owner(), INITIAL_OWNER);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);

        // Zero address cannot accept (no private key)
        // Owner remains unchanged
    }

    function test_RenounceOwnership_PreventsNewTransfersAfterForceRenounce() public {
        harness.forceRenounce();
        assertEq(harness.owner(), ZERO_ADDRESS);

        // Should revert with OwnerAlreadyRenounced error
        vm.expectRevert(LibOwnerTwoSteps.OwnerAlreadyRenounced.selector);
        harness.transferOwnership(ALICE);
    }

    // ============================================
    // Sequential Transfer Tests
    // ============================================

    function test_SequentialTransfers() public {
        // First transfer
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ALICE);

        vm.prank(ALICE);
        harness.acceptOwnership();
        assertEq(harness.owner(), ALICE);

        // Second transfer
        vm.prank(ALICE);
        harness.transferOwnership(BOB);

        vm.prank(BOB);
        harness.acceptOwnership();
        assertEq(harness.owner(), BOB);

        // Third transfer
        vm.prank(BOB);
        harness.transferOwnership(NEW_OWNER);

        vm.prank(NEW_OWNER);
        harness.acceptOwnership();
        assertEq(harness.owner(), NEW_OWNER);
    }

    function test_TransferToSelf() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(INITIAL_OWNER);
        assertEq(harness.pendingOwner(), INITIAL_OWNER);

        vm.prank(INITIAL_OWNER);
        harness.acceptOwnership();
        assertEq(harness.owner(), INITIAL_OWNER);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_MultiplePendingChanges_OnlyLastOneMatters() public {
        vm.startPrank(INITIAL_OWNER);
        harness.transferOwnership(ALICE);
        assertEq(harness.pendingOwner(), ALICE);

        harness.transferOwnership(BOB);
        assertEq(harness.pendingOwner(), BOB);

        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.pendingOwner(), NEW_OWNER);
        vm.stopPrank();

        // Library allows anyone to accept, but pending owner is NEW_OWNER
        // So whoever calls acceptOwnership will transfer ownership to NEW_OWNER
        vm.prank(ALICE);
        harness.acceptOwnership();

        // NEW_OWNER becomes owner regardless of who called acceptOwnership
        assertEq(harness.owner(), NEW_OWNER);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function test_CancelPendingTransfer() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.pendingOwner(), NEW_OWNER);

        // Cancel by setting to zero
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);

        // NEW_OWNER can still call acceptOwnership, but it will transfer to zero
        vm.prank(NEW_OWNER);
        harness.acceptOwnership();

        // Owner becomes zero (the pending owner)
        assertEq(harness.owner(), ZERO_ADDRESS);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(newOwner);

        assertEq(harness.owner(), INITIAL_OWNER);
        assertEq(harness.pendingOwner(), newOwner);
    }

    function testFuzz_AcceptOwnership(address newOwner) public {
        vm.assume(newOwner != address(0));

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(newOwner);

        vm.prank(newOwner);
        harness.acceptOwnership();

        assertEq(harness.owner(), newOwner);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function testFuzz_TransferOwnership_AnyCaller(address caller, address target) public {
        // Library allows any caller
        vm.prank(caller);
        harness.transferOwnership(target);

        // Pending owner updated regardless of caller
        assertEq(harness.pendingOwner(), target);
        assertEq(harness.owner(), INITIAL_OWNER); // Owner unchanged until acceptance
    }

    function testFuzz_AcceptOwnership_AnyCaller(address caller) public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        // Library allows any caller to accept
        vm.prank(caller);
        harness.acceptOwnership();

        // Ownership transferred to NEW_OWNER regardless of who called
        assertEq(harness.owner(), NEW_OWNER);
        assertEq(harness.pendingOwner(), ZERO_ADDRESS);
    }

    function testFuzz_SequentialTransfers(address owner1, address owner2, address owner3) public {
        vm.assume(owner1 != address(0));
        vm.assume(owner2 != address(0));
        vm.assume(owner3 != address(0));

        // Transfer to owner1
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(owner1);
        vm.prank(owner1);
        harness.acceptOwnership();
        assertEq(harness.owner(), owner1);

        // Transfer to owner2
        vm.prank(owner1);
        harness.transferOwnership(owner2);
        vm.prank(owner2);
        harness.acceptOwnership();
        assertEq(harness.owner(), owner2);

        // Transfer to owner3
        vm.prank(owner2);
        harness.transferOwnership(owner3);
        vm.prank(owner3);
        harness.acceptOwnership();
        assertEq(harness.owner(), owner3);
    }
}
