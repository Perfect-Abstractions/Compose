// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {OwnerFacet} from "../../../src/access/Owner/OwnerFacet.sol";
import {OwnerFacetHarness} from "./harnesses/OwnerFacetHarness.sol";

contract OwnerFacetTest is Test {
    OwnerFacetHarness public ownerFacet;

    address INITIAL_OWNER = makeAddr("owner");
    address NEW_OWNER = makeAddr("newOwner");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address ZERO_ADDRESS = address(0);

    /**
     * Events
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        ownerFacet = new OwnerFacetHarness();
        ownerFacet.initialize(INITIAL_OWNER);
    }

    /**
     * ============================================
     * Ownership Getter Tests
     * ============================================
     */

    function test_Owner_ReturnsCorrectInitialOwner() public view {
        assertEq(ownerFacet.owner(), INITIAL_OWNER);
    }

    function test_Owner_ReturnsZeroWhenRenounced() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ZERO_ADDRESS);

        assertEq(ownerFacet.owner(), ZERO_ADDRESS);
    }

    /**
     * ============================================
     * Transfer Ownership Tests
     * ============================================
     */

    function test_TransferOwnership_ImmediateTransfer() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(NEW_OWNER);

        assertEq(ownerFacet.owner(), NEW_OWNER);
    }

    function test_TransferOwnership_EmitsOwnershipTransferredEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, NEW_OWNER);

        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(NEW_OWNER);
    }

    function test_TransferOwnership_MultipleTransfers() public {
        /**
         * First transfer
         */
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ALICE);
        assertEq(ownerFacet.owner(), ALICE);

        /**
         * Second transfer
         */
        vm.prank(ALICE);
        ownerFacet.transferOwnership(BOB);
        assertEq(ownerFacet.owner(), BOB);

        /**
         * Third transfer
         */
        vm.prank(BOB);
        ownerFacet.transferOwnership(NEW_OWNER);
        assertEq(ownerFacet.owner(), NEW_OWNER);
    }

    function test_TransferOwnership_ToSelf() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(INITIAL_OWNER);

        assertEq(ownerFacet.owner(), INITIAL_OWNER);
    }

    function test_RevertWhen_TransferOwnership_CalledByNonOwner() public {
        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerFacet.transferOwnership(ALICE);
    }

    function test_RevertWhen_TransferOwnership_CalledByPreviousOwner() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(NEW_OWNER);

        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ALICE);
    }

    /**
     * ============================================
     * Renounce Ownership Tests
     * ============================================
     */

    function test_RenounceOwnership_SetsOwnerToZero() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ZERO_ADDRESS);

        assertEq(ownerFacet.owner(), ZERO_ADDRESS);
    }

    function test_RenounceOwnership_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ZERO_ADDRESS);

        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ZERO_ADDRESS);
    }

    function test_RenounceOwnership_PreventsAllFurtherTransfers() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ZERO_ADDRESS);

        /**
         * ALICE (non-owner) cannot transfer
         */
        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerFacet.transferOwnership(BOB);

        /**
         * BOB (non-owner) cannot transfer
         */
        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(BOB);
        ownerFacet.transferOwnership(ALICE);

        /**
         * Note: Zero address cannot make any calls since it has no private key
         */
    }

    /**
     * ============================================
     * Renounce Ownership Direct Call Tests
     * ============================================
     */

    function test_RenounceOwnership_DirectCall_SetsOwnerToZero() public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.renounceOwnership();

        assertEq(ownerFacet.owner(), ZERO_ADDRESS);
    }

    function test_RenounceOwnership_DirectCall_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ZERO_ADDRESS);

        vm.prank(INITIAL_OWNER);
        ownerFacet.renounceOwnership();
    }

    function test_RevertWhen_RenounceOwnership_CalledByNonOwner() public {
        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        vm.prank(ALICE);
        ownerFacet.renounceOwnership();
    }

    /**
     * ============================================
     * Edge Cases
     * ============================================
     */

    function test_TransferOwnership_EmitsCorrectPreviousOwner() public {
        vm.prank(INITIAL_OWNER);
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(INITIAL_OWNER, ALICE);
        ownerFacet.transferOwnership(ALICE);

        vm.prank(ALICE);
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(ALICE, BOB);
        ownerFacet.transferOwnership(BOB);
    }

    function test_StorageSlot_Consistency() public {
        bytes32 expectedSlot = keccak256("compose.owner");

        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(NEW_OWNER);

        /**
         * Read directly from storage
         */
        bytes32 storedValue = vm.load(address(ownerFacet), expectedSlot);
        address storedOwner = address(uint160(uint256(storedValue)));

        assertEq(storedOwner, NEW_OWNER);
        assertEq(ownerFacet.owner(), NEW_OWNER);
    }

    /**
     * ============================================
     * Fuzz Tests
     * ============================================
     */

    function testFuzz_TransferOwnership(address newOwner) public {
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(newOwner);

        assertEq(ownerFacet.owner(), newOwner);
    }

    function testFuzz_SequentialTransfers(address owner1, address owner2, address owner3) public {
        vm.assume(owner1 != address(0));
        vm.assume(owner2 != address(0));
        vm.assume(owner3 != address(0));

        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(owner1);
        assertEq(ownerFacet.owner(), owner1);

        vm.prank(owner1);
        ownerFacet.transferOwnership(owner2);
        assertEq(ownerFacet.owner(), owner2);

        vm.prank(owner2);
        ownerFacet.transferOwnership(owner3);
        assertEq(ownerFacet.owner(), owner3);
    }

    function testFuzz_RevertWhen_UnauthorizedCaller(address caller, address target) public {
        vm.assume(caller != INITIAL_OWNER);

        vm.prank(caller);
        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        ownerFacet.transferOwnership(target);
    }

    function testFuzz_RenouncePreventsAllTransfers(address caller, address target) public {
        vm.assume(caller != address(0));

        /**
         * Renounce ownership
         */
        vm.prank(INITIAL_OWNER);
        ownerFacet.transferOwnership(ZERO_ADDRESS);

        /**
         * No one can transfer anymore
         */
        vm.prank(caller);
        vm.expectRevert(OwnerFacet.OwnerUnauthorizedAccount.selector);
        ownerFacet.transferOwnership(target);
    }

    /**
     * ============================================
     */
}
