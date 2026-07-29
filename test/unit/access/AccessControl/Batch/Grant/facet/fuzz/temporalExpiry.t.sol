// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlGrantBatch_Base_Test
} from "test/unit/access/AccessControl/Batch/Grant/AccessControlGrantBatchBase.t.sol";
import {AccessControlGrantBatchFacet} from "src/access/AccessControl/Batch/Grant/AccessControlGrantBatchFacet.sol";

contract TemporalExpiry_AccessControlGrantBatchFacet_Test is AccessControlGrantBatch_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlGrantBatchFacet internal grantBatchFacet;

    function setUp() public override {
        super.setUp();
        grantBatchFacet = new AccessControlGrantBatchFacet();
        vm.label(address(grantBatchFacet), "AccessControlGrantBatchFacet");
        seedDefaultAdmin(address(grantBatchFacet));
    }

    function test_ShouldRevert_GrantRoleBatch_WhenCallerAdminRoleExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        address[] memory accounts = new address[](2);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        uint256 expiry = block.timestamp + 1 hours;

        address(grantBatchFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(grantBatchFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlGrantBatchFacet.AccessControlRoleExpired.selector, DEFAULT_ADMIN_ROLE, users.admin
            )
        );
        vm.prank(users.admin);
        grantBatchFacet.grantRoleBatch(role, accounts);
    }

    function test_ShouldSucceed_GrantRoleBatch_WhenCallerAdminRoleNotExpired() external {
        bytes32 role = keccak256("TEST_ROLE");
        address[] memory accounts = new address[](2);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        uint256 expiry = block.timestamp + 1 hours;

        address(grantBatchFacet).setHasRole(users.admin, DEFAULT_ADMIN_ROLE, true);
        address(grantBatchFacet).setRoleExpiry(users.admin, DEFAULT_ADMIN_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        vm.prank(users.admin);
        grantBatchFacet.grantRoleBatch(role, accounts);

        assertTrue(address(grantBatchFacet).hasRole(users.alice, role));
        assertTrue(address(grantBatchFacet).hasRole(users.bob, role));
    }
}
