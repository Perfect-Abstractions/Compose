// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlRenounce_Base_Test} from "test/unit/access/AccessControl/Renounce/AccessControlRenounceBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlRenounceFacet} from "src/access/AccessControl/Renounce/AccessControlRenounceFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RenounceRole_AccessControlRenounceFacet_Fuzz_Unit_Test is AccessControlRenounce_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlRenounceFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlRenounceFacet();
        vm.label(address(facet), "AccessControlRenounceFacet");
    }

    function testFuzz_ShouldRenounceRole_WhenSenderMatchesAccount(bytes32 role, address account) external {
        address(facet).setHasRole(account, role, true);

        vm.expectEmit(address(facet));
        emit RoleRevoked(role, account, account);

        vm.prank(account);
        facet.renounceRole(role, account);

        assertEq(address(facet).hasRole(account, role), false, "hasRole");
    }

    function testFuzz_ShouldNotEmit_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.recordLogs();
        vm.prank(account);
        facet.renounceRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "unexpected logs");
    }

    function testFuzz_ShouldRevert_WhenSenderDoesNotMatchAccount(bytes32 role, address sender, address account)
        external
    {
        vm.assume(sender != account);

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlRenounceFacet.AccessControlUnauthorizedSender.selector, sender, account)
        );
        vm.prank(sender);
        facet.renounceRole(role, account);
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(AccessControlRenounceFacet.renounceRole.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
