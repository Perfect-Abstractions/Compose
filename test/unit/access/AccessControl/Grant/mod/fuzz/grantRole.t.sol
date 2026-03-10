// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlGrant_Base_Test} from "test/unit/access/AccessControl/Grant/AccessControlGrantBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlCoreModHarness} from "test/utils/harnesses/access/AccessControl/AccessControlCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract GrantRole_AccessControlGrantMod_Fuzz_Unit_Test is AccessControlGrant_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleGranted(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCoreModHarness();
        vm.label(address(harness), "AccessControlCoreModHarness");
        seedDefaultAdmin(address(harness));
    }

    function testFuzz_ShouldReturnTrue_WhenCallerHasAdminRole(bytes32 role, address account) external {
        vm.expectEmit(address(harness));
        emit RoleGranted(role, account, users.admin);

        vm.prank(users.admin);
        bool result = harness.grantRole(role, account);

        assertEq(result, true, "grantRole");
        assertEq(address(harness).hasRole(account, role), true, "hasRole");
    }

    function testFuzz_ShouldReturnFalse_WhenAccountAlreadyHasRole(bytes32 role, address account) external {
        address(harness).setHasRole(account, role, true);

        vm.recordLogs();
        vm.prank(users.admin);
        bool result = harness.grantRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(result, false, "grantRole");
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
        harness.grantRole(role, account);
    }

    function testFuzz_ShouldReturnTrue_WhenRoleIsSelfAdmin(address caller, address account) external {
        vm.assume(caller != account);

        seedAdminRole(address(harness), MINTER_ROLE, MINTER_ROLE);
        seedRole(address(harness), MINTER_ROLE, caller);

        vm.prank(caller);
        bool result = harness.grantRole(MINTER_ROLE, account);

        assertEq(result, true, "grantRole");
        assertEq(address(harness).hasRole(account, MINTER_ROLE), true, "hasRole");
    }

    function testFuzz_ShouldGrantThroughLinearHierarchy(address role1Holder, address role2Holder, address role3Holder)
        external
    {
        seedLinearHierarchy(address(harness), MINTER_ROLE, PAUSER_ROLE, UPGRADER_ROLE);

        vm.prank(users.admin);
        assertEq(harness.grantRole(MINTER_ROLE, role1Holder), true, "grant role1");

        vm.prank(role1Holder);
        assertEq(harness.grantRole(PAUSER_ROLE, role2Holder), true, "grant role2");

        vm.prank(role2Holder);
        assertEq(harness.grantRole(UPGRADER_ROLE, role3Holder), true, "grant role3");

        assertEq(address(harness).hasRole(role3Holder, UPGRADER_ROLE), true, "hasRole");
    }

    function testFuzz_ShouldUseImmediateAdminRoleInCircularHierarchy(address caller, address account) external {
        seedAdminRole(address(harness), MINTER_ROLE, PAUSER_ROLE);
        seedAdminRole(address(harness), PAUSER_ROLE, UPGRADER_ROLE);
        seedAdminRole(address(harness), UPGRADER_ROLE, MINTER_ROLE);
        seedRole(address(harness), PAUSER_ROLE, caller);

        vm.prank(caller);
        bool result = harness.grantRole(MINTER_ROLE, account);

        assertEq(result, true, "grantRole");
        assertEq(address(harness).hasRole(account, MINTER_ROLE), true, "hasRole");
    }
}
