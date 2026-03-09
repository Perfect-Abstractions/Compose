// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlRevoke_Base_Test} from "test/unit/access/AccessControl/Revoke/AccessControlRevokeBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlRevokeFacet} from "src/access/AccessControl/Revoke/AccessControlRevokeFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RevokeRole_AccessControlRevokeFacet_Fuzz_Unit_Test is AccessControlRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlRevokeFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlRevokeFacet();
        vm.label(address(facet), "AccessControlRevokeFacet");
        seedDefaultAdmin(address(facet));
    }

    function testFuzz_ShouldRevokeRole_WhenCallerHasAdminRole(bytes32 role, address account) external {
        address(facet).setHasRole(account, role, true);

        vm.expectEmit(address(facet));
        emit RoleRevoked(role, account, users.admin);

        vm.prank(users.admin);
        facet.revokeRole(role, account);

        assertEq(address(facet).hasRole(account, role), false, "hasRole");
    }

    function testFuzz_ShouldNotEmit_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.recordLogs();
        vm.prank(users.admin);
        facet.revokeRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "unexpected logs");
        assertEq(address(facet).hasRole(account, role), false, "hasRole");
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveAdminRole(bytes32 role, address account, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlRevokeFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        facet.revokeRole(role, account);
    }

    function testFuzz_ShouldRevokeRole_WhenRoleIsSelfAdmin(address caller, address account) external {
        seedAdminRole(address(facet), MINTER_ROLE, MINTER_ROLE);
        seedRole(address(facet), MINTER_ROLE, caller);
        seedRole(address(facet), MINTER_ROLE, account);

        vm.prank(caller);
        facet.revokeRole(MINTER_ROLE, account);

        assertEq(address(facet).hasRole(account, MINTER_ROLE), false, "hasRole");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlRevokeFacet.revokeRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
