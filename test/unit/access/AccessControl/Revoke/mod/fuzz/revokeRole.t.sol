// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlRevoke_Base_Test} from "test/unit/access/AccessControl/Revoke/AccessControlRevokeBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlCoreModHarness} from "test/utils/harnesses/access/AccessControl/AccessControlCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RevokeRole_AccessControlRevokeMod_Fuzz_Unit_Test is AccessControlRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCoreModHarness();
        vm.label(address(harness), "AccessControlCoreModHarness");
        seedDefaultAdmin(address(harness));
    }

    function testFuzz_ShouldReturnTrue_WhenCallerHasAdminRole(bytes32 role, address account) external {
        address(harness).setHasRole(account, role, true);

        vm.expectEmit(address(harness));
        emit RoleRevoked(role, account, users.admin);

        vm.prank(users.admin);
        bool result = harness.revokeRole(role, account);

        assertEq(result, true, "revokeRole");
        assertEq(address(harness).hasRole(account, role), false, "hasRole");
    }

    function testFuzz_ShouldReturnFalse_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.recordLogs();
        vm.prank(users.admin);
        bool result = harness.revokeRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(result, false, "revokeRole");
        assertEq(logs.length, 0, "unexpected logs");
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveAdminRole(bytes32 role, address account, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", caller, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(caller);
        harness.revokeRole(role, account);
    }

    function testFuzz_ShouldReturnTrue_WhenRoleIsSelfAdmin(address caller, address account) external {
        seedAdminRole(address(harness), MINTER_ROLE, MINTER_ROLE);
        seedRole(address(harness), MINTER_ROLE, caller);
        seedRole(address(harness), MINTER_ROLE, account);

        vm.prank(caller);
        bool result = harness.revokeRole(MINTER_ROLE, account);

        assertEq(result, true, "revokeRole");
        assertEq(address(harness).hasRole(account, MINTER_ROLE), false, "hasRole");
    }
}
