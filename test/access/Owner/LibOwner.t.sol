// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {LibOwner} from "../../../src/access/Owner/LibOwner.sol";
import {LibOwnerHarness} from "./harnesses/LibOwnerHarness.sol";

contract LibOwnerTest is Test {
    LibOwnerHarness public harness;

    address INITIAL_OWNER = makeAddr("owner");
    address NEW_OWNER = makeAddr("newOwner");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address ZERO_ADDRESS = address(0);

    // Events
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        harness = new LibOwnerHarness();
        harness.initialize(INITIAL_OWNER);
    }

    // ============================================
    // Storage Tests
    // ============================================

    function test_GetStorage_ReturnsCorrectOwner() public view {
        assertEq(harness.owner(), INITIAL_OWNER);
        assertEq(harness.getStorageOwner(), INITIAL_OWNER);
    }

    function test_StorageSlot_UsesCorrectPosition() public {
        bytes32 expectedSlot = keccak256("compose.owner");

        // Change owner
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);

        // Read directly from storage
        bytes32 storedValue = vm.load(address(harness), expectedSlot);
        address storedOwner = address(uint160(uint256(storedValue)));

        assertEq(storedOwner, NEW_OWNER);
        assertEq(harness.owner(), NEW_OWNER);
    }

    // ============================================
    // Owner Getter Tests
    // ============================================

    function test_Owner_ReturnsCurrentOwner() public {
        assertEq(harness.owner(), INITIAL_OWNER);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.owner(), NEW_OWNER);
    }

    function test_Owner_ReturnsZeroAfterRenounce() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
        assertEq(harness.owner(), ZERO_ADDRESS);
    }

    // ============================================
    // Transfer Ownership Tests
    // ============================================

    function test_TransferOwnership_UpdatesOwner() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.owner(), NEW_OWNER);
    }

    function test_TransferOwnership_EmitsOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, NEW_OWNER);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(NEW_OWNER);
    }

    function test_TransferOwnership_AllowsTransferToZeroAddress() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
        assertEq(harness.owner(), ZERO_ADDRESS);
    }

    function test_TransferOwnership_AllowsTransferToSelf() public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(INITIAL_OWNER);
        assertEq(harness.owner(), INITIAL_OWNER);
    }

    function test_RevertWhen_TransferOwnership_FromRenouncedOwner() public {
        // Force renounce
        harness.forceRenounce();
        assertEq(harness.owner(), ZERO_ADDRESS);

        // Should revert with OwnerAlreadyRenounced error
        vm.expectRevert(LibOwner.OwnerAlreadyRenounced.selector);
        harness.transferOwnership(NEW_OWNER);
    }

    // ============================================
    // Sequential Transfer Tests
    // ============================================

    function test_MultipleTransfers() public {
        // First transfer
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ALICE);
        assertEq(harness.owner(), ALICE);

        // Second transfer
        vm.prank(ALICE);
        harness.transferOwnership(BOB);
        assertEq(harness.owner(), BOB);

        // Third transfer
        vm.prank(BOB);
        harness.transferOwnership(NEW_OWNER);
        assertEq(harness.owner(), NEW_OWNER);
    }

    // ============================================
    // Event Tests
    // ============================================

    function test_Events_CorrectPreviousOwner() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ALICE);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ALICE);

        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(ALICE, BOB);

        vm.prank(ALICE);
        harness.transferOwnership(BOB);
    }

    function test_Events_RenounceEmitsZeroAddress() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ZERO_ADDRESS);

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_RenounceOwnership_PermanentlyDisablesTransfers() public {
        // Renounce ownership
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
        assertEq(harness.owner(), ZERO_ADDRESS);

        // Should revert with OwnerAlreadyRenounced error
        vm.expectRevert(LibOwner.OwnerAlreadyRenounced.selector);
        harness.transferOwnership(ALICE);
    }

    function test_LibraryDoesNotCheckMsgSender() public {
        // The library doesn't check msg.sender - that's the facet's responsibility
        // This test verifies the library works regardless of caller
        // (In production, the facet should check permissions before calling the library)

        vm.prank(ALICE); // Not the owner
        harness.transferOwnership(BOB);
        assertEq(harness.owner(), BOB);

        // This shows the library itself doesn't enforce access control
        // Access control should be implemented in the facet that uses the library
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(newOwner);
        assertEq(harness.owner(), newOwner);
    }

    function testFuzz_MultipleTransfers(address owner1, address owner2, address owner3) public {
        vm.assume(owner1 != address(0));
        vm.assume(owner2 != address(0));

        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(owner1);
        assertEq(harness.owner(), owner1);

        vm.prank(owner1);
        harness.transferOwnership(owner2);
        assertEq(harness.owner(), owner2);

        vm.prank(owner2);
        harness.transferOwnership(owner3);
        assertEq(harness.owner(), owner3);
    }

    function testFuzz_RevertWhen_RenouncedOwnerTransfers(address target) public {
        vm.assume(target != address(0));

        // Renounce
        vm.prank(INITIAL_OWNER);
        harness.transferOwnership(ZERO_ADDRESS);
        assertEq(harness.owner(), ZERO_ADDRESS);

        // Should revert with OwnerAlreadyRenounced error
        vm.expectRevert(LibOwner.OwnerAlreadyRenounced.selector);
        harness.transferOwnership(target);
    }

    // ============================================
    // Renounce Ownership Tests (New Function)
    // ============================================

    function test_RenounceOwnership_SetsOwnerToZero() public {
        // Use the new renounceOwnership function
        harness.renounceOwnership();
        assertEq(harness.owner(), ZERO_ADDRESS);
    }

    function test_RenounceOwnership_EmitsCorrectEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ZERO_ADDRESS);

        harness.renounceOwnership();
    }

    // ============================================
    // Require Owner Tests (New Function)
    // ============================================

    function test_RequireOwner_PassesForOwner() public {
        // Should not revert when called by owner
        vm.prank(INITIAL_OWNER);
        harness.requireOwner();
    }

    function test_RevertWhen_RequireOwner_CalledByNonOwner() public {
        vm.expectRevert(LibOwner.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        harness.requireOwner();
    }

    function testFuzz_RequireOwner(address caller) public {
        if (caller == INITIAL_OWNER) {
            // Should not revert for owner
            vm.prank(caller);
            harness.requireOwner();
        } else {
            // Should revert for non-owner
            vm.expectRevert(LibOwner.OwnerUnauthorizedAccount.selector);
            vm.prank(caller);
            harness.requireOwner();
        }
    }
}
