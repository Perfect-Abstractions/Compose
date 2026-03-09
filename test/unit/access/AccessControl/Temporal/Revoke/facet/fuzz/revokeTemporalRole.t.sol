// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlTemporalRevoke_Base_Test} from "test/unit/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeBase.t.sol";
import {AccessControlTemporalRevokeFacet} from "src/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RevokeTemporalRole_AccessControlTemporalRevokeFacet_Fuzz_Unit_Test is AccessControlTemporalRevoke_Base_Test {
    using AccessControlStorageUtils for address;

    event TemporalRoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlTemporalRevokeFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlTemporalRevokeFacet();
        vm.label(address(facet), "AccessControlTemporalRevokeFacet");
        seedDefaultAdmin(address(facet));
    }

    function testFuzz_ShouldRevokeTemporalRole_WhenCallerHasAdminRole(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        seedRole(address(facet), role, account);
        seedRoleExpiry(address(facet), role, account, block.timestamp + expiryOffset);

        vm.expectEmit(address(facet));
        emit TemporalRoleRevoked(role, account, users.admin);

        vm.prank(users.admin);
        facet.revokeTemporalRole(role, account);

        assertEq(address(facet).hasRole(account, role), false, "hasRole");
        assertEq(address(facet).roleExpiry(account, role), 0, "roleExpiry");
    }

    function testFuzz_ShouldBeNoOp_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.recordLogs();
        vm.prank(users.admin);
        facet.revokeTemporalRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "unexpected logs");
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveAdminRole(bytes32 role, address account, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalRevokeFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        facet.revokeTemporalRole(role, account);
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlTemporalRevokeFacet.revokeTemporalRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
