// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlRevokeBatch_Base_Test
} from "test/unit/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchBase.t.sol";
import {
    AccessControlCombinedModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlCombinedModHarness.sol";

contract TemporalExpiry_AccessControlRevokeBatchMod_Test is AccessControlRevokeBatch_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlCombinedModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCombinedModHarness();
        vm.label(address(harness), "AccessControlCombinedModHarness");
        seedDefaultAdmin(address(harness));
    }

    function test_ShouldRevert_RevokeRoleBatch_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        address[] memory accounts = new address[](2);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        uint256 expiry = block.timestamp + 1 hours;

        seedRole(address(harness), role, users.alice);
        seedRole(address(harness), role, users.bob);

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", DEFAULT_ADMIN_ROLE, users.admin)
        );
        vm.prank(users.admin);
        harness.revokeRoleBatch(role, accounts);
    }

    function test_ShouldSucceed_RevokeRoleBatch_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        address[] memory accounts = new address[](2);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        uint256 expiry = block.timestamp + 1 hours;

        seedRole(address(harness), role, users.alice);
        seedRole(address(harness), role, users.bob);

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        harness.revokeRoleBatch(role, accounts);

        assertFalse(address(harness).hasRole(users.alice, role));
        assertFalse(address(harness).hasRole(users.bob, role));
    }
}
