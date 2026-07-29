// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlTemporalRevoke_Base_Test
} from "test/unit/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeBase.t.sol";
import {
    AccessControlCombinedModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlCombinedModHarness.sol";

contract TemporalExpiry_AccessControlTemporalRevokeMod_Test is AccessControlTemporalRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlCombinedModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCombinedModHarness();
        vm.label(address(harness), "AccessControlCombinedModHarness");
        seedDefaultAdmin(address(harness));
    }

    function test_ShouldRevert_RevokeTemporalRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 adminExpiry = block.timestamp + 1 hours;

        seedRole(address(harness), role, users.alice);

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, adminExpiry);

        vm.warp(adminExpiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", DEFAULT_ADMIN_ROLE, users.admin)
        );
        vm.prank(users.admin);
        harness.revokeTemporalRole(role, users.alice);
    }

    function test_ShouldSucceed_RevokeTemporalRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 adminExpiry = block.timestamp + 1 hours;

        seedRole(address(harness), role, users.alice);
        seedRoleExpiry(address(harness), role, users.alice, block.timestamp + 2 hours);

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, adminExpiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        harness.revokeTemporalRole(role, users.alice);

        assertFalse(address(harness).hasRole(users.alice, role));
    }
}
