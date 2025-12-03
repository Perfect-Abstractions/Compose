// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "../../../src/access/AccessControlPausable/AccessControlPausable.sol" as AccessControlPausable;
import "../../../src/access/AccessControl/AccessControl.sol" as AccessControl;
import {AccessControlPausableHarness} from "./harnesses/AccessControlPausableHarness.sol";
import {AccessControlHarness} from "../AccessControl/harnesses/AccessControlHarness.sol";

contract LibAccessControlPausableTest is Test {
    AccessControlPausableHarness public harness;
    AccessControlHarness public accessControl;

    /**
     * Test addresses
     */
    address ADMIN = makeAddr("admin");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");

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

    function setUp() public {
        /**
         * Initialize AccessControl first (shared storage)
         */
        accessControl = new AccessControlHarness();
        accessControl.initialize(ADMIN);

        /**
         * Initialize Pausable harness (uses same AccessControl storage)
         */
        harness = new AccessControlPausableHarness();
        harness.initialize(ADMIN);
    }

    /**
     * ============================================
     * IsRolePaused Tests
     * ============================================
     */

    function test_IsRolePaused_ReturnsFalseByDefault() public view {
        assertFalse(harness.isRolePaused(MINTER_ROLE));
    }

    function test_IsRolePaused_ReturnsTrueWhenPaused() public {
        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);

        assertTrue(harness.isRolePaused(MINTER_ROLE));
        assertTrue(harness.getStoragePaused(MINTER_ROLE));
    }

    /**
     * ============================================
     * PauseRole Tests
     * ============================================
     */

    function test_PauseRole_EmitsRolePausedEvent() public {
        vm.expectEmit(true, true, false, true);
        emit RolePaused(MINTER_ROLE, address(harness));

        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);
    }

    function test_PauseRole_CanBeCalledMultipleTimes() public {
        vm.startPrank(address(harness));
        harness.pauseRole(MINTER_ROLE);
        harness.pauseRole(MINTER_ROLE);
        harness.pauseRole(MINTER_ROLE);
        vm.stopPrank();

        assertTrue(harness.isRolePaused(MINTER_ROLE));
    }

    /**
     * ============================================
     * UnpauseRole Tests
     * ============================================
     */

    function test_UnpauseRole_EmitsRoleUnpausedEvent() public {
        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);

        vm.expectEmit(true, true, false, true);
        emit RoleUnpaused(MINTER_ROLE, address(harness));

        vm.prank(address(harness));
        harness.unpauseRole(MINTER_ROLE);
    }

    function test_UnpauseRole_CanBeCalledMultipleTimes() public {
        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);

        vm.startPrank(address(harness));
        harness.unpauseRole(MINTER_ROLE);
        harness.unpauseRole(MINTER_ROLE);
        harness.unpauseRole(MINTER_ROLE);
        vm.stopPrank();

        assertFalse(harness.isRolePaused(MINTER_ROLE));
    }

    function test_PauseUnpauseCycle_MultipleCycles() public {
        vm.startPrank(address(harness));

        /**
         * First cycle
         */
        harness.pauseRole(MINTER_ROLE);
        assertTrue(harness.isRolePaused(MINTER_ROLE));

        harness.unpauseRole(MINTER_ROLE);
        assertFalse(harness.isRolePaused(MINTER_ROLE));

        /**
         * Second cycle
         */
        harness.pauseRole(MINTER_ROLE);
        assertTrue(harness.isRolePaused(MINTER_ROLE));

        harness.unpauseRole(MINTER_ROLE);
        assertFalse(harness.isRolePaused(MINTER_ROLE));

        vm.stopPrank();
    }

    /**
     * ============================================
     * RequireRoleNotPaused Tests
     * ============================================
     */

    function test_RequireRoleNotPaused_PassesWhenRoleNotPaused() public {
        /**
         * Grant role to Alice
         */
        harness.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Should pass (role exists and not paused)
         */
        harness.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireRoleNotPaused_RoleIsPaused() public {
        /**
         * Grant role to Alice
         */
        harness.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Pause the role
         */
        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);

        /**
         * Should revert
         */
        vm.expectRevert(abi.encodeWithSelector(AccessControlPausable.AccessControlRolePaused.selector, MINTER_ROLE));
        harness.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireRoleNotPaused_AccountDoesNotHaveRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausable.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE
            )
        );
        harness.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_RequireRoleNotPaused_AfterUnpause() public {
        /**
         * Grant role to Alice
         */
        harness.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Pause
         */
        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);

        /**
         * Unpause
         */
        vm.prank(address(harness));
        harness.unpauseRole(MINTER_ROLE);

        /**
         * Should pass now
         */
        harness.requireRoleNotPaused(MINTER_ROLE, ALICE);
    }

    function test_PauseRole_MultipleRolesCanBePaused() public {
        vm.startPrank(address(harness));
        harness.pauseRole(MINTER_ROLE);
        harness.pauseRole(PAUSER_ROLE);
        vm.stopPrank();

        assertTrue(harness.isRolePaused(MINTER_ROLE));
        assertTrue(harness.isRolePaused(PAUSER_ROLE));
    }

    /**
     * ============================================
     * Storage Consistency Tests
     * ============================================
     */

    function test_StorageConsistency_PauseRole() public {
        vm.prank(address(harness));
        harness.pauseRole(MINTER_ROLE);

        assertTrue(harness.isRolePaused(MINTER_ROLE));
        assertTrue(harness.getStoragePaused(MINTER_ROLE));
    }

    function test_StorageConsistency_UnpauseRole() public {
        vm.startPrank(address(harness));
        harness.pauseRole(MINTER_ROLE);
        assertTrue(harness.getStoragePaused(MINTER_ROLE));

        harness.unpauseRole(MINTER_ROLE);
        assertFalse(harness.getStoragePaused(MINTER_ROLE));
        vm.stopPrank();
    }

    /**
     * ============================================
     * Fuzz Tests
     * ============================================
     */

    function testFuzz_PauseUnpauseCycle_ConsistentState(bytes32 role) public {
        vm.startPrank(address(harness));

        /**
         * Pause
         */
        harness.pauseRole(role);
        assertTrue(harness.isRolePaused(role));

        /**
         * Unpause
         */
        harness.unpauseRole(role);
        assertFalse(harness.isRolePaused(role));

        vm.stopPrank();
    }
}
