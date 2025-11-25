// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {LibAccessControlTemporal} from "../../../src/access/AccessControlTemporal/LibAccessControlTemporal.sol";
import {LibAccessControl} from "../../../src/access/AccessControl/LibAccessControl.sol";
import {LibAccessControlTemporalHarness} from "./harnesses/LibAccessControlTemporalHarness.sol";
import {LibAccessControlHarness} from "../AccessControl/harnesses/LibAccessControlHarness.sol";

contract LibAccessControlTemporalTest is Test {
    LibAccessControlTemporalHarness public harness;
    LibAccessControlHarness public accessControl;

    // Test addresses
    address ADMIN = makeAddr("admin");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");

    // Test roles
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Events
    event RoleGrantedWithExpiry(
        bytes32 indexed role, address indexed account, uint256 expiresAt, address indexed sender
    );

    function setUp() public {
        // Initialize AccessControl first (shared storage)
        accessControl = new LibAccessControlHarness();
        accessControl.initialize(ADMIN);

        // Initialize Temporal harness (uses same AccessControl storage)
        harness = new LibAccessControlTemporalHarness();
        harness.initialize(ADMIN);
    }

    // ============================================
    // GetRoleExpiry Tests
    // ============================================

    function test_GetRoleExpiry_ReturnsZeroForNonExistentRole() public view {
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), 0);
    }

    function test_GetRoleExpiry_ReturnsExpiryWhenSet() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
        assertEq(harness.getStorageExpiry(ALICE, MINTER_ROLE), expiry);
    }

    // ============================================
    // IsRoleExpired Tests
    // ============================================

    function test_IsRoleExpired_ReturnsTrueForNoRole() public view {
        assertTrue(harness.isRoleExpired(MINTER_ROLE, ALICE));
    }

    function test_IsRoleExpired_ReturnsFalseForFutureExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertFalse(harness.isRoleExpired(MINTER_ROLE, ALICE));
    }

    function test_IsRoleExpired_ReturnsTrueForPastExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        // Fast forward past expiry
        vm.warp(expiry + 1);

        assertTrue(harness.isRoleExpired(MINTER_ROLE, ALICE));
    }

    function test_IsRoleExpired_ReturnsTrueAtExactExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        // Set time to exactly expiry
        vm.warp(expiry);

        // At exact expiry time, role should be expired
        assertTrue(harness.isRoleExpired(MINTER_ROLE, ALICE));
    }

    // ============================================
    // GrantRoleWithExpiry Tests
    // ============================================

    function test_GrantRoleWithExpiry_GrantsRoleAndSetsExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.expectEmit(true, true, true, true);
        emit RoleGrantedWithExpiry(MINTER_ROLE, ALICE, expiry, address(harness));

        vm.prank(address(harness));
        bool granted = harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertTrue(granted);
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
    }

    function test_GrantRoleWithExpiry_CanUpdateExpiry() public {
        uint256 expiry1 = block.timestamp + 7 days;
        uint256 expiry2 = block.timestamp + 14 days;

        vm.startPrank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry1);
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), expiry1);

        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry2);
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), expiry2);
        vm.stopPrank();
    }

    // ============================================
    // RevokeTemporalRole Tests
    // ============================================

    function test_RevokeTemporalRole_RevokesRoleAndClearsExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.startPrank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
        vm.stopPrank();

        vm.prank(address(harness));
        bool revoked = harness.revokeTemporalRole(MINTER_ROLE, ALICE);

        assertTrue(revoked);
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), 0);
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevokeTemporalRole_ReturnsFalseWhenNoRole() public {
        vm.prank(address(harness));
        bool revoked = harness.revokeTemporalRole(MINTER_ROLE, ALICE);

        assertFalse(revoked);
        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), 0);
    }

    // ============================================
    // RequireValidRole Tests
    // ============================================

    function test_RequireValidRole_PassesWithValidExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        // Should not revert
        harness.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RequireValidRole_PassesWithoutExpiry() public {
        // Grant role without expiry
        harness.forceGrantRole(MINTER_ROLE, ALICE);

        // Should not revert (no expiry set means valid)
        harness.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireValidRole_Expired() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        // Fast forward past expiry
        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(LibAccessControlTemporal.AccessControlRoleExpired.selector, MINTER_ROLE, ALICE)
        );
        harness.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireValidRole_NoRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LibAccessControlTemporal.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE
            )
        );
        harness.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RequireValidRole_AfterRevoke() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.startPrank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);
        harness.revokeTemporalRole(MINTER_ROLE, ALICE);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                LibAccessControlTemporal.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE
            )
        );
        harness.requireValidRole(MINTER_ROLE, ALICE);
    }

    // ============================================
    // Storage Consistency Tests
    // ============================================

    function test_StorageConsistency_GrantRoleWithExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertEq(harness.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
        assertEq(harness.getStorageExpiry(ALICE, MINTER_ROLE), expiry);
    }

    function test_StorageConsistency_RevokeTemporalRole() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.startPrank(address(harness));
        harness.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);
        assertEq(harness.getStorageExpiry(ALICE, MINTER_ROLE), expiry);

        harness.revokeTemporalRole(MINTER_ROLE, ALICE);
        assertEq(harness.getStorageExpiry(ALICE, MINTER_ROLE), 0);
        vm.stopPrank();
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_GrantRoleWithExpiry_AlwaysSetsExpiry(address account, bytes32 role, uint256 expiryOffset)
        public
    {
        vm.assume(account != address(0));
        vm.assume(expiryOffset > 0); // Must be in the future
        vm.assume(expiryOffset <= 365 days); // Reasonable expiry window
        uint256 expiry = block.timestamp + expiryOffset;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(role, account, expiry);

        assertEq(harness.getRoleExpiry(role, account), expiry);
    }

    function testFuzz_IsRoleExpired_ConsistentWithExpiry(address account, bytes32 role, uint256 expiryOffset) public {
        vm.assume(account != address(0));
        vm.assume(expiryOffset > 0); // Must be in the future
        vm.assume(expiryOffset <= 365 days);
        uint256 expiry = block.timestamp + expiryOffset;

        vm.prank(address(harness));
        harness.grantRoleWithExpiry(role, account, expiry);

        // Before expiry
        assertFalse(harness.isRoleExpired(role, account));

        // After expiry
        vm.warp(expiry + 1);
        assertTrue(harness.isRoleExpired(role, account));
    }
}
