// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import {
    AccessControlRevokeBatch_Base_Test
} from "test/unit/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchBase.t.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {AccessControlCoreModHarness} from "test/harnesses/access/AccessControl/AccessControlCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract RevokeRoleBatch_AccessControlRevokeBatchMod_Unit_Test is AccessControlRevokeBatch_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    AccessControlCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlCoreModHarness();
        vm.label(address(harness), "AccessControlCoreModHarness");
        seedDefaultAdmin(address(harness));
    }

    function test_ShouldSucceedWithoutEvents_WhenAccountsArrayIsEmpty() external {
        address[] memory accounts = new address[](0);

        vm.recordLogs();
        vm.prank(users.admin);
        harness.revokeRoleBatch(MINTER_ROLE, accounts);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 0, "unexpected logs");
    }

    function test_ShouldRevokeRoleBatch_ForEachGrantedAccount() external {
        address[] memory accounts = new address[](3);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        accounts[2] = users.charlee;

        seedRole(address(harness), MINTER_ROLE, users.alice);
        seedRole(address(harness), MINTER_ROLE, users.bob);
        seedRole(address(harness), MINTER_ROLE, users.charlee);

        vm.expectEmit(address(harness));
        emit RoleRevoked(MINTER_ROLE, users.alice, users.admin);
        vm.expectEmit(address(harness));
        emit RoleRevoked(MINTER_ROLE, users.bob, users.admin);
        vm.expectEmit(address(harness));
        emit RoleRevoked(MINTER_ROLE, users.charlee, users.admin);

        vm.prank(users.admin);
        harness.revokeRoleBatch(MINTER_ROLE, accounts);

        assertEq(address(harness).hasRole(users.alice, MINTER_ROLE), false, "alice");
        assertEq(address(harness).hasRole(users.bob, MINTER_ROLE), false, "bob");
        assertEq(address(harness).hasRole(users.charlee, MINTER_ROLE), false, "charlee");
    }

    function test_ShouldSkipAccountsThatDoNotHaveRole() external {
        address[] memory accounts = new address[](3);
        accounts[0] = users.alice;
        accounts[1] = users.bob;
        accounts[2] = users.charlee;

        seedRole(address(harness), MINTER_ROLE, users.alice);

        vm.expectEmit(address(harness));
        emit RoleRevoked(MINTER_ROLE, users.alice, users.admin);

        vm.prank(users.admin);
        harness.revokeRoleBatch(MINTER_ROLE, accounts);
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveAdminRole(address caller) external {
        vm.assume(caller != users.admin);

        address[] memory accounts = new address[](1);
        accounts[0] = users.alice;

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", caller, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(caller);
        harness.revokeRoleBatch(MINTER_ROLE, accounts);
    }
}
