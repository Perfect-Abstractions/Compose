// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlAdmin_Base_Test} from "test/unit/access/AccessControl/Admin/AccessControlAdminBase.t.sol";
import {
    AccessControlCombinedModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlCombinedModHarness.sol";

contract TemporalExpiry_AccessControlAdminMod_Test is AccessControlAdmin_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlCombinedModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCombinedModHarness();
        vm.label(address(harness), "AccessControlCombinedModHarness");
        seedDefaultAdmin(address(harness));
    }

    function test_ShouldRevert_SetRoleAdmin_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        bytes32 newAdminRole = keccak256("NEW_ADMIN_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", DEFAULT_ADMIN_ROLE, users.admin)
        );
        vm.prank(users.admin);
        harness.setRoleAdmin(role, newAdminRole);
    }

    function test_ShouldSucceed_SetRoleAdmin_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        bytes32 newAdminRole = keccak256("NEW_ADMIN_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        harness.setRoleAdmin(role, newAdminRole);

        assertEq(address(harness).adminRole(role), newAdminRole);
    }
}
