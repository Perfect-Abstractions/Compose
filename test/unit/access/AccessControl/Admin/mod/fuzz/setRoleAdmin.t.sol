// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlAdmin_Base_Test} from "test/unit/access/AccessControl/Admin/AccessControlAdminBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlCoreModHarness} from "test/utils/harnesses/access/AccessControl/AccessControlCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract SetRoleAdmin_AccessControlAdminMod_Fuzz_Unit_Test is AccessControlAdmin_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleAdminChanged(bytes32 indexed _role, bytes32 indexed _previousAdminRole, bytes32 indexed _newAdminRole);

    AccessControlCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCoreModHarness();
        vm.label(address(harness), "AccessControlCoreModHarness");
        seedDefaultAdmin(address(harness));
    }

    function testFuzz_ShouldSetRoleAdmin_WhenCallerHasCurrentAdmin(bytes32 role, bytes32 newAdminRole) external {
        vm.expectEmit(address(harness));
        emit RoleAdminChanged(role, DEFAULT_ADMIN_ROLE, newAdminRole);

        vm.prank(users.admin);
        harness.setRoleAdmin(role, newAdminRole);

        assertEq(address(harness).adminRole(role), newAdminRole, "adminRole");
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveCurrentAdmin(bytes32 role, bytes32 newAdminRole, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", caller, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(caller);
        harness.setRoleAdmin(role, newAdminRole);
    }
}
