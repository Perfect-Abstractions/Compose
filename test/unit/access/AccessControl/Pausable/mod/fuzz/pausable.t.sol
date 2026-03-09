// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlPausable_Base_Test} from "test/unit/access/AccessControl/Pausable/AccessControlPausableBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlPausableModHarness} from "test/harnesses/access/AccessControl/AccessControlPausableModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract Pausable_AccessControlPausableMod_Fuzz_Unit_Test is AccessControlPausable_Base_Test {
    using AccessControlStorageUtils for address;

    event RolePaused(bytes32 indexed _role, address indexed _account);
    event RoleUnpaused(bytes32 indexed _role, address indexed _account);

    AccessControlPausableModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlPausableModHarness();
        vm.label(address(harness), "AccessControlPausableModHarness");
    }

    function testFuzz_ShouldReturnFalse_IsRolePaused_WhenRoleIsNotPaused(bytes32 role) external view {
        assertEq(harness.isRolePaused(role), false, "isRolePaused");
    }

    function testFuzz_ShouldReturnTrue_IsRolePaused_WhenRoleIsPaused(bytes32 role) external {
        seedPausedRole(address(harness), role, true);

        assertEq(harness.isRolePaused(role), true, "isRolePaused");
    }

    function testFuzz_ShouldPauseRole_ForCurrentSurfaceSemantics(bytes32 role, address caller) external {
        vm.expectEmit(address(harness));
        emit RolePaused(role, caller);

        vm.prank(caller);
        harness.pauseRole(role);

        assertEq(address(harness).isRolePaused(role), true, "isRolePaused");
    }

    function testFuzz_ShouldUnpauseRole_ForCurrentSurfaceSemantics(bytes32 role, address caller) external {
        seedPausedRole(address(harness), role, true);

        vm.expectEmit(address(harness));
        emit RoleUnpaused(role, caller);

        vm.prank(caller);
        harness.unpauseRole(role);

        assertEq(address(harness).isRolePaused(role), false, "isRolePaused");
    }

    function testFuzz_ShouldNotRevert_RequireRoleNotPaused_WhenAccountHasRoleAndRoleIsNotPaused(
        bytes32 role,
        address account
    ) external {
        seedRole(address(harness), role, account);

        harness.requireRoleNotPaused(role, account);
    }

    function testFuzz_ShouldRevert_RequireRoleNotPaused_WhenAccountDoesNotHaveRole(bytes32 role, address account)
        external
    {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role));
        harness.requireRoleNotPaused(role, account);
    }

    function testFuzz_ShouldRevert_RequireRoleNotPaused_WhenRoleIsPaused(bytes32 role, address account) external {
        seedRole(address(harness), role, account);
        seedPausedRole(address(harness), role, true);

        vm.expectRevert(abi.encodeWithSignature("AccessControlRolePaused(bytes32)", role));
        harness.requireRoleNotPaused(role, account);
    }
}
