// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {AccessControlRenounce_Base_Test} from "test/unit/access/AccessControl/Renounce/AccessControlRenounceBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlCoreModHarness} from "test/harnesses/access/AccessControl/AccessControlCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RenounceRole_AccessControlRenounceMod_Fuzz_Unit_Test is AccessControlRenounce_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCoreModHarness();
        vm.label(address(harness), "AccessControlCoreModHarness");
    }

    function testFuzz_ShouldRenounceRole_WhenSenderMatchesAccount(bytes32 role, address account) external {
        address(harness).setHasRole(account, role, true);

        vm.expectEmit(address(harness));
        emit RoleRevoked(role, account, account);

        vm.prank(account);
        harness.renounceRole(role, account);

        assertEq(address(harness).hasRole(account, role), false, "hasRole");
    }

    function testFuzz_ShouldNotEmit_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.recordLogs();
        vm.prank(account);
        harness.renounceRole(role, account);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "unexpected logs");
    }

    function testFuzz_ShouldRevert_WhenSenderDoesNotMatchAccount(bytes32 role, address sender, address account)
        external
    {
        vm.assume(sender != account);

        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedSender(address,address)", sender, account));
        vm.prank(sender);
        harness.renounceRole(role, account);
    }
}
