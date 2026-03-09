// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlAdmin_Base_Test} from "test/unit/access/AccessControl/Admin/AccessControlAdminBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlAdminFacet} from "src/access/AccessControl/Admin/AccessControlAdminFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract SetRoleAdmin_AccessControlAdminFacet_Fuzz_Unit_Test is AccessControlAdmin_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleAdminChanged(bytes32 indexed _role, bytes32 indexed _previousAdminRole, bytes32 indexed _newAdminRole);

    AccessControlAdminFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlAdminFacet();
        vm.label(address(facet), "AccessControlAdminFacet");
        seedDefaultAdmin(address(facet));
    }

    function testFuzz_ShouldSetRoleAdmin_WhenCallerHasCurrentAdmin(bytes32 role, bytes32 newAdminRole) external {
        vm.expectEmit(address(facet));
        emit RoleAdminChanged(role, DEFAULT_ADMIN_ROLE, newAdminRole);

        vm.prank(users.admin);
        facet.setRoleAdmin(role, newAdminRole);

        assertEq(address(facet).adminRole(role), newAdminRole, "adminRole");
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveCurrentAdmin(bytes32 role, bytes32 newAdminRole, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlAdminFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(caller);
        facet.setRoleAdmin(role, newAdminRole);
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlAdminFacet.setRoleAdmin.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
