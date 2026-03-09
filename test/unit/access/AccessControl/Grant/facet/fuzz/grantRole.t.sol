// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlGrant_Base_Test} from "test/unit/access/AccessControl/Grant/AccessControlGrantBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlGrantFacet} from "src/access/AccessControl/Grant/AccessControlGrantFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract GrantRole_AccessControlGrantFacet_Fuzz_Unit_Test is AccessControlGrant_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleGranted(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlGrantFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlGrantFacet();
        vm.label(address(facet), "AccessControlGrantFacet");
        seedDefaultAdmin(address(facet));
    }

    function testFuzz_ShouldGrantRole_WhenCallerHasAdminRole(bytes32 role, address account) external {
        vm.expectEmit(address(facet));
        emit RoleGranted(role, account, users.admin);

        vm.prank(users.admin);
        facet.grantRole(role, account);

        assertEq(address(facet).hasRole(account, role), true, "hasRole");
    }

    function testFuzz_ShouldNotEmitAgain_WhenAccountAlreadyHasRole(bytes32 role, address account) external {
        address(facet).setHasRole(account, role, true);

        vm.recordLogs();
        vm.prank(users.admin);
        facet.grantRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "unexpected logs");
        assertEq(address(facet).hasRole(account, role), true, "hasRole");
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveAdminRole(bytes32 role, address account, address caller)
        external
    {
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlGrantFacet.AccessControlUnauthorizedAccount.selector, caller, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(caller);
        facet.grantRole(role, account);
    }

    function testFuzz_ShouldGrantRole_WhenRoleIsSelfAdmin(address caller, address account) external {
        vm.assume(caller != account);
        seedAdminRole(address(facet), MINTER_ROLE, MINTER_ROLE);
        seedRole(address(facet), MINTER_ROLE, caller);

        vm.expectEmit(address(facet));
        emit RoleGranted(MINTER_ROLE, account, caller);

        vm.prank(caller);
        facet.grantRole(MINTER_ROLE, account);

        assertEq(address(facet).hasRole(account, MINTER_ROLE), true, "hasRole");
    }

    function testFuzz_ShouldGrantThroughLinearHierarchy(address role1Holder, address role2Holder, address role3Holder)
        external
    {
        seedLinearHierarchy(address(facet), MINTER_ROLE, PAUSER_ROLE, UPGRADER_ROLE);

        vm.prank(users.admin);
        facet.grantRole(MINTER_ROLE, role1Holder);

        vm.prank(role1Holder);
        facet.grantRole(PAUSER_ROLE, role2Holder);

        vm.prank(role2Holder);
        facet.grantRole(UPGRADER_ROLE, role3Holder);

        assertEq(address(facet).hasRole(role1Holder, MINTER_ROLE), true, "role1");
        assertEq(address(facet).hasRole(role2Holder, PAUSER_ROLE), true, "role2");
        assertEq(address(facet).hasRole(role3Holder, UPGRADER_ROLE), true, "role3");
    }

    function testFuzz_ShouldUseImmediateAdminRoleInCircularHierarchy(address caller, address account) external {
        seedAdminRole(address(facet), MINTER_ROLE, PAUSER_ROLE);
        seedAdminRole(address(facet), PAUSER_ROLE, UPGRADER_ROLE);
        seedAdminRole(address(facet), UPGRADER_ROLE, MINTER_ROLE);
        seedRole(address(facet), PAUSER_ROLE, caller);

        vm.prank(caller);
        facet.grantRole(MINTER_ROLE, account);

        assertEq(address(facet).hasRole(account, MINTER_ROLE), true, "hasRole");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlGrantFacet.grantRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
