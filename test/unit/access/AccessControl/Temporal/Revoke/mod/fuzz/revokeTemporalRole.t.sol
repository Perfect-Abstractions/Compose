// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlTemporalRevoke_Base_Test
} from "test/unit/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeBase.t.sol";
import {
    AccessControlTemporalModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlTemporalModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RevokeTemporalRole_AccessControlTemporalRevokeMod_Fuzz_Unit_Test is AccessControlTemporalRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    event TemporalRoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlTemporalModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlTemporalModHarness();
        vm.label(address(harness), "AccessControlTemporalModHarness");
        seedDefaultAdmin(address(harness));
    }

    function testFuzz_ShouldRevokeTemporalRole_WhenCallerHasAdminRole(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        seedRole(address(harness), role, account);
        seedRoleExpiry(address(harness), role, account, block.timestamp + expiryOffset);

        vm.expectEmit(address(harness));
        emit TemporalRoleRevoked(role, account, users.admin);

        vm.prank(users.admin);
        harness.revokeTemporalRole(role, account);

        assertEq(address(harness).hasRole(account, role), false, "hasRole");
        assertEq(address(harness).roleExpiry(account, role), 0, "roleExpiry");
    }

    function testFuzz_ShouldBeNoOp_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.recordLogs();
        vm.prank(users.admin);
        harness.revokeTemporalRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
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
        harness.revokeTemporalRole(role, account);
    }
}
