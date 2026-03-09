// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlData_Base_Test} from "test/unit/access/AccessControl/Data/AccessControlDataBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlCoreModHarness} from "test/harnesses/access/AccessControl/AccessControlCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract Data_AccessControlMod_Fuzz_Unit_Test is AccessControlData_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCoreModHarness();
        vm.label(address(harness), "AccessControlCoreModHarness");
        seedDefaultAdmin(address(harness));
    }

    function testFuzz_ShouldReturnTrue_HasRole_WhenAccountHasRole(address account, bytes32 role) external {
        address(harness).setHasRole(account, role, true);

        assertEq(harness.hasRole(role, account), true, "hasRole");
    }

    function testFuzz_ShouldReturnFalse_HasRole_WhenAccountDoesNotHaveRole(address account, bytes32 role)
        external
        view
    {
        assertEq(harness.hasRole(role, account), false, "hasRole");
    }

    function testFuzz_ShouldNotRevert_RequireRole_WhenAccountHasRole(address account, bytes32 role) external {
        address(harness).setHasRole(account, role, true);

        harness.requireRole(role, account);
    }

    function testFuzz_ShouldRevert_RequireRole_WhenAccountDoesNotHaveRole(address account, bytes32 role) external {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role));
        harness.requireRole(role, account);
    }

    function testFuzz_ShouldReturnDefaultAdminRole_GetRoleAdmin_WhenAdminNotSet(bytes32 role) external view {
        assertEq(address(harness).adminRole(role), DEFAULT_ADMIN_ROLE, "getRoleAdmin");
    }

    function testFuzz_ShouldReturnStoredAdminRole_GetRoleAdmin(bytes32 role, bytes32 adminRole) external {
        address(harness).setAdminRole(role, adminRole);

        assertEq(address(harness).adminRole(role), adminRole, "getRoleAdmin");
    }

    function test_ShouldReturnZero_DEFAULT_ADMIN_ROLE_VALUE() external view {
        assertEq(harness.DEFAULT_ADMIN_ROLE_VALUE(), bytes32(0), "DEFAULT_ADMIN_ROLE");
    }
}
