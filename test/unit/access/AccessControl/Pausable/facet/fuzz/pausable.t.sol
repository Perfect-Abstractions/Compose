// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlPausable_Base_Test} from "test/unit/access/AccessControl/Pausable/AccessControlPausableBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlPausableFacet} from "src/access/AccessControl/Pausable/AccessControlPausableFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract Pausable_AccessControlPausableFacet_Fuzz_Unit_Test is AccessControlPausable_Base_Test {
    using AccessControlStorageUtils for address;

    event RolePaused(bytes32 indexed _role, address indexed _account);
    event RoleUnpaused(bytes32 indexed _role, address indexed _account);

    AccessControlPausableFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlPausableFacet();
        vm.label(address(facet), "AccessControlPausableFacet");
        seedDefaultAdmin(address(facet));
    }

    function testFuzz_ShouldReturnFalse_IsRolePaused_WhenRoleIsNotPaused(bytes32 role) external view {
        assertEq(facet.isRolePaused(role), false, "isRolePaused");
    }

    function testFuzz_ShouldReturnTrue_IsRolePaused_WhenRoleIsPaused(bytes32 role) external {
        seedPausedRole(address(facet), role, true);

        assertEq(facet.isRolePaused(role), true, "isRolePaused");
    }

    function testFuzz_ShouldPauseRole_WhenCallerHasAdminRole(bytes32 role) external {
        vm.expectEmit(address(facet));
        emit RolePaused(role, users.admin);

        vm.prank(users.admin);
        facet.pauseRole(role);

        assertEq(address(facet).isRolePaused(role), true, "isRolePaused");
    }

    function testFuzz_ShouldRevert_PauseRole_WhenCallerDoesNotHaveAdminRole(bytes32 role, address caller) external {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        facet.pauseRole(role);
    }

    function testFuzz_ShouldUnpauseRole_WhenCallerHasAdminRole(bytes32 role) external {
        seedPausedRole(address(facet), role, true);

        vm.expectEmit(address(facet));
        emit RoleUnpaused(role, users.admin);

        vm.prank(users.admin);
        facet.unpauseRole(role);

        assertEq(address(facet).isRolePaused(role), false, "isRolePaused");
    }

    function testFuzz_ShouldRevert_UnpauseRole_WhenCallerDoesNotHaveAdminRole(bytes32 role, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        facet.unpauseRole(role);
    }

    function testFuzz_ShouldNotRevert_RequireRoleNotPaused_WhenAccountHasRoleAndRoleIsNotPaused(
        bytes32 role,
        address account
    ) external {
        seedRole(address(facet), role, account);

        facet.requireRoleNotPaused(role, account);
    }

    function testFuzz_ShouldRevert_RequireRoleNotPaused_WhenAccountDoesNotHaveRole(bytes32 role, address account)
        external
    {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlPausableFacet.AccessControlUnauthorizedAccount.selector, account, role)
        );
        facet.requireRoleNotPaused(role, account);
    }

    function testFuzz_ShouldRevert_RequireRoleNotPaused_WhenRoleIsPaused(bytes32 role, address account) external {
        seedRole(address(facet), role, account);
        seedPausedRole(address(facet), role, true);

        vm.expectRevert(abi.encodeWithSelector(AccessControlPausableFacet.AccessControlRolePaused.selector, role));
        facet.requireRoleNotPaused(role, account);
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            AccessControlPausableFacet.isRolePaused.selector,
            AccessControlPausableFacet.pauseRole.selector,
            AccessControlPausableFacet.unpauseRole.selector,
            AccessControlPausableFacet.requireRoleNotPaused.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
