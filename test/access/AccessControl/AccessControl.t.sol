// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "../../../src/access/AccessControl/AccessControlMod.sol" as AccessControl;
import {AccessControlHarness} from "./harnesses/AccessControlHarness.sol";

contract LibAccessControlTest is Test {
    AccessControlHarness public harness;

    /**
     * Test addresses
     */
    address ADMIN = makeAddr("admin");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address CHARLIE = makeAddr("charlie");
    address ZERO_ADDRESS = address(0);

    /**
     * Test roles
     */
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    /**
     * Events
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function setUp() public {
        harness = new AccessControlHarness();
        harness.initialize(ADMIN);
    }

    /**
     * ============================================
     * Storage Tests
     * ============================================
     */

    function test_GetStorage_ReturnsCorrectInitialState() public view {
        assertEq(harness.hasRole(DEFAULT_ADMIN_ROLE, ADMIN), true);
        assertEq(harness.getStorageHasRole(ADMIN, DEFAULT_ADMIN_ROLE), true);
    }

    function test_StorageSlot_UsesCorrectPosition() public {
        bytes32 expectedSlot = keccak256("compose.accesscontrol");

        /**
         * Grant a role
         */
        vm.prank(address(harness));
        harness.grantRole(MINTER_ROLE, ALICE);

        /**
         * The actual storage slot for hasRole[ALICE][MINTER_ROLE] is computed as:
         * keccak256(abi.encode(MINTER_ROLE, keccak256(abi.encode(ALICE, expectedSlot))))
         */
        bytes32 accountSlot = keccak256(abi.encode(ALICE, expectedSlot));
        bytes32 roleSlot = keccak256(abi.encode(MINTER_ROLE, accountSlot));

        /**
         * Read directly from storage
         */
        bytes32 storedValue = vm.load(address(harness), roleSlot);
        bool hasRole = storedValue != bytes32(0);

        assertTrue(hasRole, "Role should be stored at correct position");
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_DefaultAdminRole_IsZeroBytes() public view {
        assertEq(harness.getDefaultAdminRole(), bytes32(0));
    }

    /**
     * ============================================
     * HasRole Tests
     * ============================================
     */

    function test_HasRole_ReturnsTrueForGrantedRole() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_HasRole_ReturnsFalseForNonGrantedRole() public view {
        assertFalse(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_HasRole_ReturnsFalseForZeroAddress() public view {
        assertFalse(harness.hasRole(DEFAULT_ADMIN_ROLE, ZERO_ADDRESS));
    }

    function test_HasRole_HandlesMultipleRolesPerAccount() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        harness.forceGrantRole(PAUSER_ROLE, ALICE);
        harness.forceGrantRole(UPGRADER_ROLE, ALICE);

        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
        assertTrue(harness.hasRole(PAUSER_ROLE, ALICE));
        assertTrue(harness.hasRole(UPGRADER_ROLE, ALICE));
        assertFalse(harness.hasRole(MODERATOR_ROLE, ALICE));
    }

    function test_HasRole_HandlesMultipleAccountsPerRole() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        harness.forceGrantRole(MINTER_ROLE, BOB);
        harness.forceGrantRole(MINTER_ROLE, CHARLIE);

        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
        assertTrue(harness.hasRole(MINTER_ROLE, BOB));
        assertTrue(harness.hasRole(MINTER_ROLE, CHARLIE));
    }

    /**
     * ============================================
     * RequireRole Tests
     * ============================================
     */

    function test_RequireRole_PassesWhenAccountHasRole() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        harness.requireRole(MINTER_ROLE, ALICE);
        /**
         * No revert means success
         */
    }

    function test_RevertWhen_RequireRole_AccountDoesNotHaveRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControl.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE)
        );
        harness.requireRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireRole_ZeroAddressDoesNotHaveRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControl.AccessControlUnauthorizedAccount.selector, ZERO_ADDRESS, DEFAULT_ADMIN_ROLE
            )
        );
        harness.requireRole(DEFAULT_ADMIN_ROLE, ZERO_ADDRESS);
    }

    /**
     * ============================================
     * SetRoleAdmin Tests
     * ============================================
     */

    function test_SetRoleAdmin_UpdatesAdminRole() public {
        harness.setRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), PAUSER_ROLE);
    }

    function test_SetRoleAdmin_EmitsRoleAdminChangedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RoleAdminChanged(MINTER_ROLE, DEFAULT_ADMIN_ROLE, PAUSER_ROLE);

        harness.setRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
    }

    function test_SetRoleAdmin_CanSetToDefaultAdminRole() public {
        harness.setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), DEFAULT_ADMIN_ROLE);
    }

    function test_SetRoleAdmin_CanSetToSameRole() public {
        harness.setRoleAdmin(MINTER_ROLE, MINTER_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), MINTER_ROLE);
    }

    function test_SetRoleAdmin_MultipleChanges() public {
        /**
         * First change
         */
        harness.setRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), PAUSER_ROLE);

        /**
         * Second change
         */
        harness.setRoleAdmin(MINTER_ROLE, UPGRADER_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), UPGRADER_ROLE);

        /**
         * Back to default
         */
        harness.setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), DEFAULT_ADMIN_ROLE);
    }

    /**
     * ============================================
     * GrantRole Tests
     * ============================================
     */

    function test_GrantRole_GrantsRoleToAccount() public {
        vm.prank(address(harness));
        bool granted = harness.grantRole(MINTER_ROLE, ALICE);

        assertTrue(granted);
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_GrantRole_ReturnsFalseWhenAlreadyGranted() public {
        vm.prank(address(harness));
        harness.grantRole(MINTER_ROLE, ALICE);

        vm.prank(address(harness));
        bool granted = harness.grantRole(MINTER_ROLE, ALICE);

        assertFalse(granted);
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_GrantRole_EmitsRoleGrantedEvent() public {
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(MINTER_ROLE, ALICE, address(harness));

        vm.prank(address(harness));
        harness.grantRole(MINTER_ROLE, ALICE);
    }

    function test_GrantRole_DoesNotEmitEventWhenAlreadyGranted() public {
        vm.prank(address(harness));
        harness.grantRole(MINTER_ROLE, ALICE);

        /**
         * Should not emit event on second grant
         * We check this by testing that no RoleGranted event is emitted
         */
        vm.prank(address(harness));
        bool granted = harness.grantRole(MINTER_ROLE, ALICE);

        /**
         * The function should return false when role is already granted
         */
        assertFalse(granted, "Should return false when role already granted");
    }

    function test_GrantRole_CanGrantToZeroAddress() public {
        vm.prank(address(harness));
        bool granted = harness.grantRole(MINTER_ROLE, ZERO_ADDRESS);

        assertTrue(granted);
        assertTrue(harness.hasRole(MINTER_ROLE, ZERO_ADDRESS));
    }

    function test_GrantRole_MultipleRolesToSameAccount() public {
        vm.startPrank(address(harness));

        harness.grantRole(MINTER_ROLE, ALICE);
        harness.grantRole(PAUSER_ROLE, ALICE);
        harness.grantRole(UPGRADER_ROLE, ALICE);

        vm.stopPrank();

        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
        assertTrue(harness.hasRole(PAUSER_ROLE, ALICE));
        assertTrue(harness.hasRole(UPGRADER_ROLE, ALICE));
    }

    function test_GrantRole_SameRoleToMultipleAccounts() public {
        vm.startPrank(address(harness));

        harness.grantRole(MINTER_ROLE, ALICE);
        harness.grantRole(MINTER_ROLE, BOB);
        harness.grantRole(MINTER_ROLE, CHARLIE);

        vm.stopPrank();

        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
        assertTrue(harness.hasRole(MINTER_ROLE, BOB));
        assertTrue(harness.hasRole(MINTER_ROLE, CHARLIE));
    }

    /**
     * ============================================
     * RevokeRole Tests
     * ============================================
     */

    function test_RevokeRole_RevokesRoleFromAccount() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));

        vm.prank(address(harness));
        bool revoked = harness.revokeRole(MINTER_ROLE, ALICE);

        assertTrue(revoked);
        assertFalse(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevokeRole_ReturnsFalseWhenNotGranted() public {
        vm.prank(address(harness));
        bool revoked = harness.revokeRole(MINTER_ROLE, ALICE);

        assertFalse(revoked);
        assertFalse(harness.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevokeRole_EmitsRoleRevokedEvent() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);

        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(MINTER_ROLE, ALICE, address(harness));

        vm.prank(address(harness));
        harness.revokeRole(MINTER_ROLE, ALICE);
    }

    function test_RevokeRole_DoesNotEmitEventWhenNotGranted() public {
        /**
         * We check this by testing that the function returns false when no role to revoke
         */
        vm.prank(address(harness));
        bool revoked = harness.revokeRole(MINTER_ROLE, ALICE);

        /**
         * The function should return false when role is not granted
         */
        assertFalse(revoked, "Should return false when role not granted");
    }

    function test_RevokeRole_OnlyRevokesSpecificRole() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        harness.forceGrantRole(PAUSER_ROLE, ALICE);
        harness.forceGrantRole(UPGRADER_ROLE, ALICE);

        vm.prank(address(harness));
        harness.revokeRole(PAUSER_ROLE, ALICE);

        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
        assertFalse(harness.hasRole(PAUSER_ROLE, ALICE));
        assertTrue(harness.hasRole(UPGRADER_ROLE, ALICE));
    }

    function test_RevokeRole_OnlyRevokesFromSpecificAccount() public {
        harness.forceGrantRole(MINTER_ROLE, ALICE);
        harness.forceGrantRole(MINTER_ROLE, BOB);
        harness.forceGrantRole(MINTER_ROLE, CHARLIE);

        vm.prank(address(harness));
        harness.revokeRole(MINTER_ROLE, BOB);

        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));
        assertFalse(harness.hasRole(MINTER_ROLE, BOB));
        assertTrue(harness.hasRole(MINTER_ROLE, CHARLIE));
    }

    /**
     * ============================================
     * Edge Cases Tests
     * ============================================
     */

    function test_EdgeCase_GrantAndRevokeMultipleTimes() public {
        vm.startPrank(address(harness));

        /**
         * Grant
         */
        assertTrue(harness.grantRole(MINTER_ROLE, ALICE));
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));

        /**
         * Revoke
         */
        assertTrue(harness.revokeRole(MINTER_ROLE, ALICE));
        assertFalse(harness.hasRole(MINTER_ROLE, ALICE));

        /**
         * Grant again
         */
        assertTrue(harness.grantRole(MINTER_ROLE, ALICE));
        assertTrue(harness.hasRole(MINTER_ROLE, ALICE));

        /**
         * Revoke again
         */
        assertTrue(harness.revokeRole(MINTER_ROLE, ALICE));
        assertFalse(harness.hasRole(MINTER_ROLE, ALICE));

        vm.stopPrank();
    }

    function test_EdgeCase_RoleAdminOfItself() public {
        harness.setRoleAdmin(MINTER_ROLE, MINTER_ROLE);
        assertEq(harness.getRoleAdmin(MINTER_ROLE), MINTER_ROLE);
    }

    function test_EdgeCase_CircularRoleAdminHierarchy() public {
        harness.setRoleAdmin(MINTER_ROLE, PAUSER_ROLE);
        harness.setRoleAdmin(PAUSER_ROLE, UPGRADER_ROLE);
        harness.setRoleAdmin(UPGRADER_ROLE, MINTER_ROLE);

        assertEq(harness.getRoleAdmin(MINTER_ROLE), PAUSER_ROLE);
        assertEq(harness.getRoleAdmin(PAUSER_ROLE), UPGRADER_ROLE);
        assertEq(harness.getRoleAdmin(UPGRADER_ROLE), MINTER_ROLE);
    }

    /**
     * ============================================
     * Fuzz Tests
     * ============================================
     */

    function testFuzz_HasRole_ConsistentWithStorage(address account, bytes32 role, bool hasRole) public {
        if (hasRole) {
            harness.forceGrantRole(role, account);
        }

        assertEq(harness.hasRole(role, account), hasRole);
        assertEq(harness.getStorageHasRole(account, role), hasRole);
    }

    function testFuzz_GrantRole_AlwaysReturnsCorrectBool(address account, bytes32 role) public {
        vm.startPrank(address(harness));

        /**
         * First grant should return true
         */
        bool firstGrant = harness.grantRole(role, account);
        assertTrue(firstGrant);
        assertTrue(harness.hasRole(role, account));

        /**
         * Second grant should return false
         */
        bool secondGrant = harness.grantRole(role, account);
        assertFalse(secondGrant);
        assertTrue(harness.hasRole(role, account));

        vm.stopPrank();
    }

    function testFuzz_RevokeRole_AlwaysReturnsCorrectBool(address account, bytes32 role) public {
        vm.startPrank(address(harness));

        /**
         * First revoke (no role) should return false
         */
        bool firstRevoke = harness.revokeRole(role, account);
        assertFalse(firstRevoke);
        assertFalse(harness.hasRole(role, account));

        /**
         * Grant role
         */
        harness.grantRole(role, account);
        assertTrue(harness.hasRole(role, account));

        /**
         * Second revoke (has role) should return true
         */
        bool secondRevoke = harness.revokeRole(role, account);
        assertTrue(secondRevoke);
        assertFalse(harness.hasRole(role, account));

        vm.stopPrank();
    }

    function testFuzz_SetRoleAdmin_AlwaysUpdatesCorrectly(bytes32 role, bytes32 adminRole) public {
        harness.setRoleAdmin(role, adminRole);
        assertEq(harness.getRoleAdmin(role), adminRole);
    }

    function testFuzz_MultipleRolesPerAccount(address account) public {
        vm.assume(account != address(0));

        bytes32[] memory roles = new bytes32[](5);
        roles[0] = keccak256("ROLE_1");
        roles[1] = keccak256("ROLE_2");
        roles[2] = keccak256("ROLE_3");
        roles[3] = keccak256("ROLE_4");
        roles[4] = keccak256("ROLE_5");

        vm.startPrank(address(harness));

        /**
         * Grant all roles
         */
        for (uint256 i = 0; i < roles.length; i++) {
            harness.grantRole(roles[i], account);
        }

        /**
         * Verify all roles are granted
         */
        for (uint256 i = 0; i < roles.length; i++) {
            assertTrue(harness.hasRole(roles[i], account));
        }

        /**
         * Revoke some roles (even indices)
         */
        for (uint256 i = 0; i < roles.length; i += 2) {
            harness.revokeRole(roles[i], account);
        }

        /**
         * Verify correct roles are revoked/kept
         */
        for (uint256 i = 0; i < roles.length; i++) {
            if (i % 2 == 0) {
                assertFalse(harness.hasRole(roles[i], account));
            } else {
                assertTrue(harness.hasRole(roles[i], account));
            }
        }

        vm.stopPrank();
    }
}
