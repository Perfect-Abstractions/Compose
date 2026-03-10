// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlData_Base_Test} from "test/unit/access/AccessControl/Data/AccessControlDataBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlDataFacet} from "src/access/AccessControl/Data/AccessControlDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract Data_AccessControlDataFacet_Fuzz_Unit_Test is AccessControlData_Base_Test {
    using AccessControlStorageUtils for address;

    AccessControlDataFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlDataFacet();
        vm.label(address(facet), "AccessControlDataFacet");
        seedDefaultAdmin(address(facet));
    }

    function testFuzz_ShouldReturnTrue_HasRole_WhenAccountHasRole(address account, bytes32 role) external {
        address(facet).setHasRole(account, role, true);

        assertEq(facet.hasRole(role, account), true, "hasRole");
    }

    function testFuzz_ShouldReturnFalse_HasRole_WhenAccountDoesNotHaveRole(address account, bytes32 role)
        external
        view
    {
        assertEq(facet.hasRole(role, account), false, "hasRole");
    }

    function testFuzz_ShouldNotRevert_RequireRole_WhenAccountHasRole(address account, bytes32 role) external {
        address(facet).setHasRole(account, role, true);

        facet.requireRole(role, account);
    }

    function testFuzz_ShouldRevert_RequireRole_WhenAccountDoesNotHaveRole(address account, bytes32 role) external {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlDataFacet.AccessControlUnauthorizedAccount.selector, account, role)
        );
        facet.requireRole(role, account);
    }

    function testFuzz_ShouldReturnDefaultAdminRole_GetRoleAdmin_WhenAdminNotSet(bytes32 role) external view {
        assertEq(facet.getRoleAdmin(role), DEFAULT_ADMIN_ROLE, "getRoleAdmin");
    }

    function testFuzz_ShouldReturnStoredAdminRole_GetRoleAdmin(bytes32 role, bytes32 adminRole) external {
        address(facet).setAdminRole(role, adminRole);

        assertEq(facet.getRoleAdmin(role), adminRole, "getRoleAdmin");
    }
}
