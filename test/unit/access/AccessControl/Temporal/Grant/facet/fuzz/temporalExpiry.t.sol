// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlTemporalGrant_Base_Test
} from "test/unit/access/AccessControl/Temporal/Grant/AccessControlTemporalGrantBase.t.sol";
import {
    AccessControlTemporalGrantFacet
} from "src/access/AccessControl/Temporal/Grant/AccessControlTemporalGrantFacet.sol";

contract TemporalExpiry_AccessControlTemporalGrantFacet_Test is AccessControlTemporalGrant_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlTemporalGrantFacet internal temporalGrantFacet;

    function setUp() public override {
        super.setUp();
        temporalGrantFacet = new AccessControlTemporalGrantFacet();
        vm.label(address(temporalGrantFacet), "AccessControlTemporalGrantFacet");
        seedDefaultAdmin(address(temporalGrantFacet));
    }

    function test_ShouldRevert_GrantRoleWithExpiry_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 adminExpiry = block.timestamp + 1 hours;
        uint256 roleExpiry = block.timestamp + 2 hours;

        address(temporalGrantFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(temporalGrantFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, adminExpiry);

        vm.warp(adminExpiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalGrantFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        temporalGrantFacet.grantRoleWithExpiry(role, users.alice, roleExpiry);
    }

    function test_ShouldSucceed_GrantRoleWithExpiry_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 adminExpiry = block.timestamp + 2 hours;
        uint256 roleExpiry = block.timestamp + 1 hours;

        address(temporalGrantFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(temporalGrantFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, adminExpiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        temporalGrantFacet.grantRoleWithExpiry(role, users.alice, roleExpiry);

        assertTrue(address(temporalGrantFacet).hasRole(users.alice, role));
        assertEq(address(temporalGrantFacet).roleExpiry(users.alice, role), roleExpiry);
    }
}
