// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlRevoke_Base_Test} from "test/unit/access/AccessControl/Revoke/AccessControlRevokeBase.t.sol";
import {AccessControlRevokeFacet} from "src/access/AccessControl/Revoke/AccessControlRevokeFacet.sol";

contract TemporalExpiry_AccessControlRevokeFacet_Test is AccessControlRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlRevokeFacet internal revokeFacet;

    function setUp() public override {
        super.setUp();
        revokeFacet = new AccessControlRevokeFacet();
        vm.label(address(revokeFacet), "AccessControlRevokeFacet");
        seedDefaultAdmin(address(revokeFacet));
    }

    function test_ShouldRevert_RevokeRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(revokeFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(revokeFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlRevokeFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        revokeFacet.revokeRole(role, users.alice);
    }

    function test_ShouldSucceed_RevokeRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(revokeFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(revokeFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        seedRole(address(revokeFacet), role, users.alice);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        revokeFacet.revokeRole(role, users.alice);

        assertFalse(address(revokeFacet).hasRole(users.alice, role));
    }
}
