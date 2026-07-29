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
    AccessControlTemporalRevokeFacet
} from "src/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeFacet.sol";

contract TemporalExpiry_AccessControlTemporalRevokeFacet_Test is AccessControlTemporalRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlTemporalRevokeFacet internal temporalRevokeFacet;

    function setUp() public override {
        super.setUp();
        temporalRevokeFacet = new AccessControlTemporalRevokeFacet();
        vm.label(address(temporalRevokeFacet), "AccessControlTemporalRevokeFacet");
        seedDefaultAdmin(address(temporalRevokeFacet));
    }

    function test_ShouldRevert_RevokeTemporalRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 adminExpiry = block.timestamp + 1 hours;

        seedRole(address(temporalRevokeFacet), role, users.alice);

        address(temporalRevokeFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(temporalRevokeFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, adminExpiry);

        vm.warp(adminExpiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalRevokeFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        temporalRevokeFacet.revokeTemporalRole(role, users.alice);
    }

    function test_ShouldSucceed_RevokeTemporalRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 adminExpiry = block.timestamp + 1 hours;

        seedRole(address(temporalRevokeFacet), role, users.alice);
        seedRoleExpiry(address(temporalRevokeFacet), role, users.alice, block.timestamp + 2 hours);

        address(temporalRevokeFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(temporalRevokeFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, adminExpiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        temporalRevokeFacet.revokeTemporalRole(role, users.alice);

        assertFalse(address(temporalRevokeFacet).hasRole(users.alice, role));
    }
}
