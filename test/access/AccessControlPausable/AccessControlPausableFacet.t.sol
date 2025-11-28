// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {AccessControlPausableFacet} from "../../../src/access/AccessControlPausable/AccessControlPausableFacet.sol";
import {AccessControlFacet} from "../../../src/access/AccessControl/AccessControlFacet.sol";
import {AccessControlPausableFacetHarness} from "./harnesses/AccessControlPausableFacetHarness.sol";
import {AccessControlFacetHarness} from "../AccessControl/harnesses/AccessControlFacetHarness.sol";

contract AccessControlPausableFacetTest is Test {
    AccessControlPausableFacetHarness public pausableFacet;
    AccessControlFacetHarness public accessControl;

    /**
     * Test addresses
     */
    address ADMIN = makeAddr("admin");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");
    address CHARLIE = makeAddr("charlie");

    /**
     * Test roles
     */
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * Events
     */
    event RolePaused(bytes32 indexed role, address indexed account);
    event RoleUnpaused(bytes32 indexed role, address indexed account);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    function setUp() public {
        /**
         * Initialize AccessControl first (shared storage)
         */
        accessControl = new AccessControlFacetHarness();
        accessControl.initialize(ADMIN);

        /**
         * Initialize PausableFacet (uses same AccessControl storage)
         */
        pausableFacet = new AccessControlPausableFacetHarness();
        pausableFacet.initialize(ADMIN);
    }

    /**
     * ============================================
     * IsRolePaused Tests
     * ============================================
     */

    function test_IsRolePaused_ReturnsFalseByDefault() public view {
        assertFalse(pausableFacet.isRolePaused(MINTER_ROLE));
    }

    function test_IsRolePaused_ReturnsTrueWhenPaused() public {
        /**
         * Grant role first
         */
        vm.prank(ADMIN);
        accessControl.grantRole(MINTER_ROLE, ALICE);

        /**
         * Pause the role
         */
        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);

        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));
    }

    /**
     * ============================================
     * PauseRole Tests
     * ============================================
     */

    function test_PauseRole_SucceedsWhenCallerIsAdmin() public {
        vm.expectEmit(true, true, false, true);
        emit RolePaused(MINTER_ROLE, ADMIN);

        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);

        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));
        assertTrue(pausableFacet.getStoragePaused(MINTER_ROLE));
    }

    function test_PauseRole_CanBeCalledMultipleTimes() public {
        vm.startPrank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);
        pausableFacet.pauseRole(MINTER_ROLE);
        pausableFacet.pauseRole(MINTER_ROLE);
        vm.stopPrank();

        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));
    }

    function test_RevertWhen_PauseRole_CallerIsNotAdmin() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlUnauthorizedAccount.selector, ALICE, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        pausableFacet.pauseRole(MINTER_ROLE);
    }

    function test_PauseRole_MultipleRolesCanBePaused() public {
        vm.startPrank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);
        pausableFacet.pauseRole(PAUSER_ROLE);
        vm.stopPrank();

        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));
        assertTrue(pausableFacet.isRolePaused(PAUSER_ROLE));
    }

    /**
     * ============================================
     * UnpauseRole Tests
     * ============================================
     */

    function test_UnpauseRole_SucceedsWhenCallerIsAdmin() public {
        /**
         * First pause
         */
        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);
        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));

        /**
         * Then unpause
         */
        vm.expectEmit(true, true, false, true);
        emit RoleUnpaused(MINTER_ROLE, ADMIN);

        vm.prank(ADMIN);
        pausableFacet.unpauseRole(MINTER_ROLE);

        assertFalse(pausableFacet.isRolePaused(MINTER_ROLE));
    }

    function test_UnpauseRole_CanBeCalledMultipleTimes() public {
        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);

        vm.startPrank(ADMIN);
        pausableFacet.unpauseRole(MINTER_ROLE);
        pausableFacet.unpauseRole(MINTER_ROLE);
        pausableFacet.unpauseRole(MINTER_ROLE);
        vm.stopPrank();

        assertFalse(pausableFacet.isRolePaused(MINTER_ROLE));
    }

    function test_RevertWhen_UnpauseRole_CallerIsNotAdmin() public {
        /**
         * First pause with admin
         */
        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);

        /**
         * Then try to unpause without admin role
         */
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlUnauthorizedAccount.selector, ALICE, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        pausableFacet.unpauseRole(MINTER_ROLE);
    }

    function test_PauseUnpauseCycle_MultipleCycles() public {
        vm.startPrank(ADMIN);

        /**
         * First cycle
         */
        pausableFacet.pauseRole(MINTER_ROLE);
        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));

        pausableFacet.unpauseRole(MINTER_ROLE);
        assertFalse(pausableFacet.isRolePaused(MINTER_ROLE));

        /**
         * Second cycle
         */
        pausableFacet.pauseRole(MINTER_ROLE);
        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));

        pausableFacet.unpauseRole(MINTER_ROLE);
        assertFalse(pausableFacet.isRolePaused(MINTER_ROLE));

        vm.stopPrank();
    }

    /**
     * ============================================
     * RequireRoleNotPaused Tests
     * ============================================
     */

    function test_RequireRoleNotPaused_PassesWhenRoleNotPaused() public {
        /**
         * Grant role to Alice using harness (direct storage manipulation)
         */
        pausableFacet.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Should pass (role exists and not paused)
         */
        pausableFacet.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireRoleNotPaused_RoleIsPaused() public {
        /**
         * Grant role to Alice using harness
         */
        pausableFacet.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Pause the role
         */
        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);

        /**
         * Should revert
         */
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlPausableFacet.AccessControlRolePaused.selector, MINTER_ROLE)
        );
        pausableFacet.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireRoleNotPaused_AccountDoesNotHaveRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE
            )
        );
        pausableFacet.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_RequireRoleNotPaused_AfterUnpause() public {
        /**
         * Grant role to Alice using harness
         */
        pausableFacet.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Pause
         */
        vm.prank(ADMIN);
        pausableFacet.pauseRole(MINTER_ROLE);

        /**
         * Unpause
         */
        vm.prank(ADMIN);
        pausableFacet.unpauseRole(MINTER_ROLE);

        /**
         * Should pass now
         */
        pausableFacet.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    /**
     * ============================================
     * Custom Admin Role Tests
     * ============================================
     */

    function test_PauseRole_WithCustomRoleAdmin() public {
        /**
         * Set up custom admin using harness
         */
        pausableFacet.forceGrantRole(PAUSER_ROLE, BOB);
        pausableFacet.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);

        /**
         * Bob can pause MINTER_ROLE
         */
        vm.expectEmit(true, true, false, true);
        emit RolePaused(MINTER_ROLE, BOB);

        vm.prank(BOB);
        pausableFacet.pauseRole(MINTER_ROLE);

        assertTrue(pausableFacet.isRolePaused(MINTER_ROLE));
    }

    function test_UnpauseRole_WithCustomRoleAdmin() public {
        /**
         * Set up custom admin using harness
         */
        pausableFacet.forceGrantRole(PAUSER_ROLE, BOB);
        pausableFacet.forceSetRoleAdmin(MINTER_ROLE, PAUSER_ROLE);

        /**
         * Pause with Bob
         */
        vm.prank(BOB);
        pausableFacet.pauseRole(MINTER_ROLE);

        /**
         * Unpause with Bob
         */
        vm.expectEmit(true, true, false, true);
        emit RoleUnpaused(MINTER_ROLE, BOB);

        vm.prank(BOB);
        pausableFacet.unpauseRole(MINTER_ROLE);

        assertFalse(pausableFacet.isRolePaused(MINTER_ROLE));
    }
}
