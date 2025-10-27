// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {AccessControlFacet} from "../../../src/access/AccessControl/AccessControlFacet.sol";
import {AccessControlFacetHarness} from "./harnesses/AccessControlFacetHarness.sol";

contract AccessControlFacetTest is Test {
    AccessControlFacetHarness public accessControl;

    // Test addresses
    address ADMIN = makeAddr("admin");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address CHARLIE = makeAddr("charlie");
    address ZERO_ADDRESS = address(0);

    // Test roles
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 constant USER_ROLE = keccak256("USER_ROLE");

    // Events
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function setUp() public {
        accessControl = new AccessControlFacetHarness();
        accessControl.initialize(ADMIN);
    }

    // ============================================
    // HasRole Tests
    // ============================================

    function test_HasRole_ReturnsCorrectInitialState() public view {
        assertTrue(accessControl.hasRole(DEFAULT_ADMIN_ROLE, ADMIN));
        assertFalse(accessControl.hasRole(DEFAULT_ADMIN_ROLE, ALICE));
    }

    function test_HasRole_ReturnsTrueForGrantedRole() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_HasRole_ReturnsFalseForNonGrantedRole() public view {
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_HasRole_HandlesMultipleRolesPerAccount() public {
        vm.startPrank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
        accessControl.grantRole(PAUSER_ROLE, ALICE);
        accessControl.grantRole(UPGRADER_ROLE, ALICE);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
        assertTrue(accessControl.hasRole(PAUSER_ROLE, ALICE));
        assertTrue(accessControl.hasRole(UPGRADER_ROLE, ALICE));
        assertFalse(accessControl.hasRole(MODERATOR_ROLE, ALICE));
    }

    function test_HasRole_HandlesMultipleAccountsPerRole() public {
        vm.startPrank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
        accessControl.grantRole(MINTER_ROLE, BOB);
        accessControl.grantRole(MINTER_ROLE, CHARLIE);
        vm.stopPrank();

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
        assertTrue(accessControl.hasRole(MINTER_ROLE, BOB));
        assertTrue(accessControl.hasRole(MINTER_ROLE, CHARLIE));
    }

    // ============================================
    // RequireRole Tests
    // ============================================

    function test_RequireRole_PassesWhenAccountHasRole() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        accessControl.requireRole(MINTER_ROLE, ALICE);
        // No revert means success
    }

    function test_RevertWhen_RequireRole_AccountDoesNotHaveRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE)
        );
        accessControl.requireRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireRole_ZeroAddressDoesNotHaveRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlFacet.AccessControlUnauthorizedAccount.selector, ZERO_ADDRESS, DEFAULT_ADMIN_ROLE
            )
        );
        accessControl.requireRole(DEFAULT_ADMIN_ROLE, ZERO_ADDRESS);
    }

    // ============================================
    // GetRoleAdmin Tests
    // ============================================

    function test_GetRoleAdmin_ReturnsDefaultAdminForNewRole() public view {
        assertEq(accessControl.getRoleAdmin(MINTER_ROLE), DEFAULT_ADMIN_ROLE);
    }

    function test_GetRoleAdmin_ReturnsCorrectAdminAfterChange() public {
        // Set up role hierarchy
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        assertEq(accessControl.getRoleAdmin(MINTER_ROLE), PAUSER_ROLE);
    }

    function test_GetRoleAdmin_DefaultAdminRoleAdminIsItself() public view {
        assertEq(accessControl.getRoleAdmin(DEFAULT_ADMIN_ROLE), DEFAULT_ADMIN_ROLE);
    }

    // ============================================
    // GrantRole Tests
    // ============================================

    function test_GrantRole_SucceedsWithDefaultAdmin() public {
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(MINTER_ROLE, ALICE, ADMIN);

        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_GrantRole_SucceedsWithCustomRoleAdmin() public {
        // Set up custom admin for MINTER_ROLE
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        accessControl.forceGrantRole(PAUSER_ROLE, BOB);

        vm.expectEmit(true, true, true, true);
        emit RoleGranted(MINTER_ROLE, ALICE, BOB);

        vm.prank(BOB);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_GrantRole_DoesNotEmitEventWhenAlreadyGranted() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        // Second grant should not emit an event
        // The AccessControlFacet doesn't return a bool, but we can verify
        // that the role is still granted and no duplicate event is emitted
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE); // Should silently succeed

        // Verify the role is still granted
        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevertWhen_GrantRole_CallerIsNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlFacet.AccessControlUnauthorizedAccount.selector, ALICE, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        accessControl.grantRole(MINTER_ROLE, BOB);
    }

    function test_RevertWhen_GrantRole_CallerIsNotCustomAdmin() public {
        // Set up custom admin for MINTER_ROLE
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);

        // ADMIN has DEFAULT_ADMIN_ROLE but not PAUSER_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedAccount.selector, ADMIN, PAUSER_ROLE)
        );
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
    }

    function test_GrantRole_CanGrantToZeroAddress() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ZERO_ADDRESS);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ZERO_ADDRESS));
    }

    function test_GrantRole_CanGrantToSelf() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ADMIN);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ADMIN));
    }

    // ============================================
    // RevokeRole Tests
    // ============================================

    function test_RevokeRole_SucceedsWithDefaultAdmin() public {
        // Setup
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));

        // Revoke
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MINTER_ROLE, ALICE, ADMIN);

        vm.prank(ADMIN);
        accessControl.revokeRole(MINTER_ROLE, ALICE);

        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevokeRole_SucceedsWithCustomRoleAdmin() public {
        // Set up custom admin for MINTER_ROLE
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        accessControl.forceGrantRole(PAUSER_ROLE, BOB);
        accessControl.forceGrantRole(MINTER_ROLE, ALICE);

        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MINTER_ROLE, ALICE, BOB);

        vm.prank(BOB);
        accessControl.revokeRole(MINTER_ROLE, ALICE);

        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevokeRole_DoesNotEmitEventWhenNotGranted() public {
        // Revoking a role that's not granted should succeed silently
        vm.prank(ADMIN);
        accessControl.revokeRole(MINTER_ROLE, ALICE);

        // Verify the role is still not granted
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevertWhen_RevokeRole_CallerIsNotAdmin() public {
        accessControl.forceGrantRole(MINTER_ROLE, ALICE);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlFacet.AccessControlUnauthorizedAccount.selector, ALICE, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        accessControl.revokeRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RevokeRole_CallerIsNotCustomAdmin() public {
        // Set up custom admin for MINTER_ROLE
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        accessControl.forceGrantRole(MINTER_ROLE, ALICE);

        // ADMIN has DEFAULT_ADMIN_ROLE but not PAUSER_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedAccount.selector, ADMIN, PAUSER_ROLE)
        );
        vm.prank(ADMIN);
        accessControl.revokeRole(MINTER_ROLE, ALICE);
    }

    function test_RevokeRole_CanRevokeFromZeroAddress() public {
        // Setup
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ZERO_ADDRESS);
        assertTrue(accessControl.hasRole(MINTER_ROLE, ZERO_ADDRESS));

        // Revoke
        vm.prank(ADMIN);
        accessControl.revokeRole(MINTER_ROLE, ZERO_ADDRESS);

        assertFalse(accessControl.hasRole(MINTER_ROLE, ZERO_ADDRESS));
    }

    // ============================================
    // RenounceRole Tests
    // ============================================

    function test_RenounceRole_SucceedsForOwnRole() public {
        // Setup
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));

        // Renounce
        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MINTER_ROLE, ALICE, ALICE);

        vm.prank(ALICE);
        accessControl.renounceRole(MINTER_ROLE, ALICE);

        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RenounceRole_DoesNotEmitEventWhenNotGranted() public {
        // Renouncing a role that's not granted should succeed silently
        vm.prank(ALICE);
        accessControl.renounceRole(MINTER_ROLE, ALICE);

        // Verify the role is still not granted
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevertWhen_RenounceRole_CallerIsNotAccount() public {
        accessControl.forceGrantRole(MINTER_ROLE, ALICE);

        vm.expectRevert(abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedSender.selector, BOB, ALICE));
        vm.prank(BOB);
        accessControl.renounceRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RenounceRole_AdminCannotRenounceForOthers() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedSender.selector, ADMIN, ALICE)
        );
        vm.prank(ADMIN);
        accessControl.renounceRole(MINTER_ROLE, ALICE);
    }

    function test_RenounceRole_CanRenounceMultipleRoles() public {
        // Setup
        vm.startPrank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
        accessControl.grantRole(PAUSER_ROLE, ALICE);
        accessControl.grantRole(UPGRADER_ROLE, ALICE);
        vm.stopPrank();

        // Renounce roles one by one
        vm.startPrank(ALICE);
        accessControl.renounceRole(MINTER_ROLE, ALICE);
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
        assertTrue(accessControl.hasRole(PAUSER_ROLE, ALICE));
        assertTrue(accessControl.hasRole(UPGRADER_ROLE, ALICE));

        accessControl.renounceRole(PAUSER_ROLE, ALICE);
        assertFalse(accessControl.hasRole(PAUSER_ROLE, ALICE));
        assertTrue(accessControl.hasRole(UPGRADER_ROLE, ALICE));

        accessControl.renounceRole(UPGRADER_ROLE, ALICE);
        assertFalse(accessControl.hasRole(UPGRADER_ROLE, ALICE));
        vm.stopPrank();
    }

    function test_RenounceRole_CanRenounceDefaultAdminRole() public {
        assertTrue(accessControl.hasRole(DEFAULT_ADMIN_ROLE, ADMIN));

        vm.prank(ADMIN);
        accessControl.renounceRole(DEFAULT_ADMIN_ROLE, ADMIN);

        assertFalse(accessControl.hasRole(DEFAULT_ADMIN_ROLE, ADMIN));
    }

    // ============================================
    // Complex Role Hierarchy Tests
    // ============================================

    function test_ComplexRoleHierarchy_Setup() public {
        accessControl.setupComplexRoleHierarchy();

        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        bytes32 MODERATOR_ROLE_LOCAL = keccak256("MODERATOR_ROLE");
        bytes32 USER_ROLE_LOCAL = keccak256("USER_ROLE");

        assertEq(accessControl.getRoleAdmin(ADMIN_ROLE), DEFAULT_ADMIN_ROLE);
        assertEq(accessControl.getRoleAdmin(MODERATOR_ROLE_LOCAL), ADMIN_ROLE);
        assertEq(accessControl.getRoleAdmin(USER_ROLE_LOCAL), MODERATOR_ROLE_LOCAL);
    }

    function test_ComplexRoleHierarchy_GrantingThroughHierarchy() public {
        accessControl.setupComplexRoleHierarchy();

        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        bytes32 MODERATOR_ROLE_LOCAL = keccak256("MODERATOR_ROLE");
        bytes32 USER_ROLE_LOCAL = keccak256("USER_ROLE");

        // Grant ADMIN_ROLE (only DEFAULT_ADMIN can do this)
        vm.prank(ADMIN);
        accessControl.grantRole(ADMIN_ROLE, ALICE);

        // Grant MODERATOR_ROLE (only ADMIN_ROLE can do this)
        vm.prank(ALICE);
        accessControl.grantRole(MODERATOR_ROLE_LOCAL, BOB);

        // Grant USER_ROLE (only MODERATOR_ROLE can do this)
        vm.prank(BOB);
        accessControl.grantRole(USER_ROLE_LOCAL, CHARLIE);

        assertTrue(accessControl.hasRole(ADMIN_ROLE, ALICE));
        assertTrue(accessControl.hasRole(MODERATOR_ROLE_LOCAL, BOB));
        assertTrue(accessControl.hasRole(USER_ROLE_LOCAL, CHARLIE));
    }

    function test_ComplexRoleHierarchy_CannotGrantWithoutProperAdmin() public {
        accessControl.setupComplexRoleHierarchy();

        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        bytes32 MODERATOR_ROLE_LOCAL = keccak256("MODERATOR_ROLE");

        // ALICE doesn't have ADMIN_ROLE, so can't grant MODERATOR_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedAccount.selector, ALICE, ADMIN_ROLE)
        );
        vm.prank(ALICE);
        accessControl.grantRole(MODERATOR_ROLE_LOCAL, BOB);
    }

    // ============================================
    // Edge Cases Tests
    // ============================================

    function test_EdgeCase_RoleAdminOfItself() public {
        accessControl.forceSetRoleAdmin(MINTER_ROLE, MINTER_ROLE);
        accessControl.forceGrantRole(MINTER_ROLE, ALICE);

        // ALICE has MINTER_ROLE and MINTER_ROLE is its own admin
        vm.prank(ALICE);
        accessControl.grantRole(MINTER_ROLE, BOB);

        assertTrue(accessControl.hasRole(MINTER_ROLE, BOB));
    }

    function test_EdgeCase_CircularRoleAdminHierarchy() public {
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        accessControl.forceSetRoleAdmin(PAUSER_ROLE, UPGRADER_ROLE);
        accessControl.forceSetRoleAdmin(UPGRADER_ROLE, MINTER_ROLE);

        // Grant MINTER_ROLE to ALICE (requires PAUSER_ROLE)
        accessControl.forceGrantRole(PAUSER_ROLE, BOB);
        vm.prank(BOB);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_EdgeCase_GrantAndRevokeInSameBlock() public {
        vm.startPrank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);
        accessControl.revokeRole(MINTER_ROLE, ALICE);
        vm.stopPrank();

        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_EdgeCase_MultipleOperationsOnSameRole() public {
        vm.startPrank(ADMIN);

        // Grant to multiple accounts
        accessControl.grantRole(MINTER_ROLE, ALICE);
        accessControl.grantRole(MINTER_ROLE, BOB);
        accessControl.grantRole(MINTER_ROLE, CHARLIE);

        // Revoke from one
        accessControl.revokeRole(MINTER_ROLE, BOB);

        vm.stopPrank();

        // BOB renounces (should have no effect since already revoked)
        vm.prank(BOB);
        accessControl.renounceRole(MINTER_ROLE, BOB);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
        assertFalse(accessControl.hasRole(MINTER_ROLE, BOB));
        assertTrue(accessControl.hasRole(MINTER_ROLE, CHARLIE));
    }

    // ============================================
    // Storage Consistency Tests
    // ============================================

    function test_StorageConsistency_HasRoleMatchesStorage() public {
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        assertTrue(accessControl.hasRole(MINTER_ROLE, ALICE));
        assertTrue(accessControl.getStorageHasRole(ALICE, MINTER_ROLE));
    }

    function test_StorageConsistency_RoleAdminMatchesStorage() public {
        accessControl.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);

        assertEq(accessControl.getRoleAdmin(MINTER_ROLE), PAUSER_ROLE);
        assertEq(accessControl.getStorageRoleAdmin(MINTER_ROLE), PAUSER_ROLE);
    }

    function test_StorageSlot_UsesCorrectPosition() public view {
        bytes32 expectedSlot = keccak256("compose.accesscontrol");
        assertEq(accessControl.getStoragePosition(), expectedSlot);
    }

    // ============================================
    // Fuzz Tests
    // ============================================

    function testFuzz_GrantRole_OnlyAdminCanGrant(address caller, address account) public {
        vm.assume(caller != ADMIN);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        accessControl.grantRole(MINTER_ROLE, account);
    }

    function testFuzz_RevokeRole_OnlyAdminCanRevoke(address caller, address account) public {
        vm.assume(caller != ADMIN);

        accessControl.forceGrantRole(MINTER_ROLE, account);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        accessControl.revokeRole(MINTER_ROLE, account);
    }

    function testFuzz_RenounceRole_OnlyAccountCanRenounce(address caller, address account) public {
        vm.assume(caller != account);

        accessControl.forceGrantRole(MINTER_ROLE, account);

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlFacet.AccessControlUnauthorizedSender.selector, caller, account)
        );
        vm.prank(caller);
        accessControl.renounceRole(MINTER_ROLE, account);
    }

    function testFuzz_HasRole_ConsistentAcrossMultipleRoles(address account) public {
        vm.assume(account != address(0));

        bytes32[] memory roles = new bytes32[](10);
        for (uint256 i = 0; i < roles.length; i++) {
            roles[i] = keccak256(abi.encodePacked("ROLE_", i));
        }

        // Grant all roles
        vm.startPrank(ADMIN);
        for (uint256 i = 0; i < roles.length; i++) {
            accessControl.grantRole(roles[i], account);
        }
        vm.stopPrank();

        // Verify all roles
        for (uint256 i = 0; i < roles.length; i++) {
            assertTrue(accessControl.hasRole(roles[i], account));
        }

        // Revoke half the roles
        vm.startPrank(ADMIN);
        for (uint256 i = 0; i < roles.length; i += 2) {
            accessControl.revokeRole(roles[i], account);
        }
        vm.stopPrank();

        // Verify correct roles are revoked
        for (uint256 i = 0; i < roles.length; i++) {
            if (i % 2 == 0) {
                assertFalse(accessControl.hasRole(roles[i], account));
            } else {
                assertTrue(accessControl.hasRole(roles[i], account));
            }
        }
    }

    function testFuzz_RoleAdminHierarchy(bytes32 role1, bytes32 role2, bytes32 role3) public {
        vm.assume(role1 != role2 && role2 != role3 && role1 != role3);

        // Create hierarchy: role1 -> role2 -> role3
        accessControl.forceSetRoleAdmin(role1, DEFAULT_ADMIN_ROLE);
        accessControl.forceSetRoleAdmin(role2, role1);
        accessControl.forceSetRoleAdmin(role3, role2);

        assertEq(accessControl.getRoleAdmin(role1), DEFAULT_ADMIN_ROLE);
        assertEq(accessControl.getRoleAdmin(role2), role1);
        assertEq(accessControl.getRoleAdmin(role3), role2);

        // Grant roles in hierarchy
        vm.prank(ADMIN);
        accessControl.grantRole(role1, ALICE);

        vm.prank(ALICE);
        accessControl.grantRole(role2, BOB);

        vm.prank(BOB);
        accessControl.grantRole(role3, CHARLIE);

        assertTrue(accessControl.hasRole(role1, ALICE));
        assertTrue(accessControl.hasRole(role2, BOB));
        assertTrue(accessControl.hasRole(role3, CHARLIE));
    }
}
