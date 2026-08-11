// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlPausable_Base_Test} from "test/unit/access/AccessControl/Pausable/AccessControlPausableBase.t.sol";
import {AccessControlPausableFacet} from "src/access/AccessControl/Pausable/AccessControlPausableFacet.sol";
import {
    AccessControlCombinedModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlCombinedModHarness.sol";

contract TemporalExpiry_AccessControlPausableFacet_Test is AccessControlPausable_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlPausableFacet internal pausableFacet;
    AccessControlCombinedModHarness internal harness;

    function setUp() public override {
        super.setUp();
        pausableFacet = new AccessControlPausableFacet();
        harness = new AccessControlCombinedModHarness();
        vm.label(address(pausableFacet), "AccessControlPausableFacet");
        vm.label(address(harness), "AccessControlCombinedModHarness");
        seedDefaultAdmin(address(harness));
        seedDefaultAdmin(address(pausableFacet));
    }

    function test_ShouldRevert_PauseRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(pausableFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(pausableFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        pausableFacet.pauseRole(role);
    }

    function test_ShouldSucceed_PauseRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        pausableFacet.pauseRole(role);

        assertTrue(pausableFacet.isRolePaused(role));
    }

    function test_ShouldRevert_UnpauseRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        seedPausedRole(address(pausableFacet), role, true);

        address(pausableFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(pausableFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlPausableFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        pausableFacet.unpauseRole(role);
    }

    function test_ShouldSucceed_UnpauseRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        seedPausedRole(address(pausableFacet), role, true);

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(DEFAULT_ADMIN_ROLE, users.admin, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        pausableFacet.unpauseRole(role);

        assertFalse(pausableFacet.isRolePaused(role));
    }
}
