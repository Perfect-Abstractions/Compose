// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {
    AccessControlTemporalGrant_Base_Test
} from "test/unit/access/AccessControl/Temporal/Grant/AccessControlTemporalGrantBase.t.sol";
import {
    AccessControlTemporalModHarness
} from "test/utils/harnesses/access/AccessControl/AccessControlTemporalModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract GrantRoleWithExpiry_AccessControlTemporalGrantMod_Fuzz_Unit_Test is AccessControlTemporalGrant_Base_Test {
    using AccessControlStorageUtils for address;

    event RoleGrantedWithExpiry(
        bytes32 indexed _role, address indexed _account, uint256 _expiresAt, address indexed _sender
    );

    AccessControlTemporalModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlTemporalModHarness();
        vm.label(address(harness), "AccessControlTemporalModHarness");
        seedDefaultAdmin(address(harness));
    }

    function testFuzz_ShouldGrantRoleWithExpiry_WhenCallerHasAdminRole(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiresAt = block.timestamp + expiryOffset;

        vm.expectEmit(address(harness));
        emit RoleGrantedWithExpiry(role, account, expiresAt, users.admin);

        vm.prank(users.admin);
        harness.grantRoleWithExpiry(role, account, expiresAt);

        assertEq(address(harness).hasRole(account, role), true, "hasRole");
        assertEq(address(harness).roleExpiry(account, role), expiresAt, "roleExpiry");
    }

    function testFuzz_ShouldRevert_WhenExpiryIsNotInTheFuture(bytes32 role, address account, uint256 expiresAt)
        external
    {
        vm.assume(expiresAt <= block.timestamp);

        vm.expectRevert(abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", role, account));
        vm.prank(users.admin);
        harness.grantRoleWithExpiry(role, account, expiresAt);
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveAdminRole(
        bytes32 role,
        address account,
        uint256 expiryOffset,
        address caller
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);
        vm.assume(caller != users.admin);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", caller, DEFAULT_ADMIN_ROLE)
        );
        vm.prank(caller);
        harness.grantRoleWithExpiry(role, account, block.timestamp + expiryOffset);
    }
}
