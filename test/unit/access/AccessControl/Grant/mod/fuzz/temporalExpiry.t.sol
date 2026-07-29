// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlGrant_Base_Test} from "test/unit/access/AccessControl/Grant/AccessControlGrantBase.t.sol";
import {
    AccessControlCombinedModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlCombinedModHarness.sol";

contract TemporalExpiry_AccessControlGrantMod_Test is AccessControlGrant_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlCombinedModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCombinedModHarness();
        vm.label(address(harness), "AccessControlCombinedModHarness");
        seedDefaultAdmin(address(harness));
    }

    function test_ShouldRevert_GrantRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", DEFAULT_ADMIN_ROLE, users.admin)
        );
        vm.prank(users.admin);
        harness.grantRole(role, users.alice);
    }

    function test_ShouldSucceed_GrantRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        harness.grantRole(role, users.alice);

        assertTrue(address(harness).hasRole(users.alice, role));
    }

    function test_ShouldSucceed_GrantRole_WhenCallerHasPermanentAdminRole() external {
        bytes32 role = keccak256("TEST_ROLE");

        vm.prank(users.admin);
        harness.grantRole(role, users.alice);

        assertTrue(address(harness).hasRole(users.alice, role));
    }
}
