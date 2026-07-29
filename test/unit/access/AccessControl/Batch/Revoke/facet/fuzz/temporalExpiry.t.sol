// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlRevokeBatch_Base_Test
} from "test/unit/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchBase.t.sol";
import {AccessControlRevokeBatchFacet} from "src/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchFacet.sol";

contract TemporalExpiry_AccessControlRevokeBatchFacet_Test is AccessControlRevokeBatch_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlRevokeBatchFacet internal revokeBatchFacet;

    function setUp() public override {
        super.setUp();
        revokeBatchFacet = new AccessControlRevokeBatchFacet();
        vm.label(address(revokeBatchFacet), "AccessControlRevokeBatchFacet");
        seedDefaultAdmin(address(revokeBatchFacet));
    }

    function test_ShouldRevert_RevokeRoleBatch_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        address[] memory accounts = new address[](2);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        uint256 expiry = block.timestamp + 1 hours;

        seedRole(address(revokeBatchFacet), role, users.alice);
        seedRole(address(revokeBatchFacet), role, users.bob);

        address(revokeBatchFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(revokeBatchFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlRevokeBatchFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        revokeBatchFacet.revokeRoleBatch(role, accounts);
    }

    function test_ShouldSucceed_RevokeRoleBatch_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        address[] memory accounts = new address[](2);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        uint256 expiry = block.timestamp + 1 hours;

        seedRole(address(revokeBatchFacet), role, users.alice);
        seedRole(address(revokeBatchFacet), role, users.bob);

        address(revokeBatchFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(revokeBatchFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        revokeBatchFacet.revokeRoleBatch(role, accounts);

        assertFalse(address(revokeBatchFacet).hasRole(users.alice, role));
        assertFalse(address(revokeBatchFacet).hasRole(users.bob, role));
    }
}
