// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlGrant_Base_Test} from "test/unit/access/AccessControl/Grant/AccessControlGrantBase.t.sol";
import {AccessControlGrantFacet} from "src/access/AccessControl/Grant/AccessControlGrantFacet.sol";

contract TemporalExpiry_AccessControlGrantFacet_Test is AccessControlGrant_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlGrantFacet internal grantFacet;

    function setUp() public override {
        super.setUp();
        grantFacet = new AccessControlGrantFacet();
        vm.label(address(grantFacet), "AccessControlGrantFacet");
        seedDefaultAdmin(address(grantFacet));
    }

    function test_ShouldRevert_GrantRole_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(grantFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(grantFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlGrantFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        grantFacet.grantRole(role, users.alice);
    }

    function test_ShouldSucceed_GrantRole_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(grantFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(grantFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        grantFacet.grantRole(role, users.alice);

        assertTrue(address(grantFacet).hasRole(users.alice, role));
    }

    function test_ShouldSucceed_GrantRole_WhenCallerHasPermanentAdminRole() external {
        bytes32 role = keccak256("TEST_ROLE");

        vm.prank(users.admin);
        grantFacet.grantRole(role, users.alice);

        assertTrue(address(grantFacet).hasRole(users.alice, role));
    }
}
