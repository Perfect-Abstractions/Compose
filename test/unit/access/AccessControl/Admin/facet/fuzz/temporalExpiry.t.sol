// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlAdmin_Base_Test} from "test/unit/access/AccessControl/Admin/AccessControlAdminBase.t.sol";
import {AccessControlAdminFacet} from "src/access/AccessControl/Admin/AccessControlAdminFacet.sol";

contract TemporalExpiry_AccessControlAdminFacet_Test is AccessControlAdmin_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlAdminFacet internal adminFacet;

    function setUp() public override {
        super.setUp();
        adminFacet = new AccessControlAdminFacet();
        vm.label(address(adminFacet), "AccessControlAdminFacet");
        seedDefaultAdmin(address(adminFacet));
    }

    function test_ShouldRevert_SetRoleAdmin_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        bytes32 newAdminRole = keccak256("NEW_ADMIN_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(adminFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(adminFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlAdminFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        adminFacet.setRoleAdmin(role, newAdminRole);
    }

    function test_ShouldSucceed_SetRoleAdmin_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        bytes32 newAdminRole = keccak256("NEW_ADMIN_ROLE");
        uint256 expiry = block.timestamp + 1 hours;

        address(adminFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(adminFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        adminFacet.setRoleAdmin(role, newAdminRole);

        assertEq(address(adminFacet).adminRole(role), newAdminRole);
    }
}
