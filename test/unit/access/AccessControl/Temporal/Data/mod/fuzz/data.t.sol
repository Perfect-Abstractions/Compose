// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    AccessControlTemporalData_Base_Test
} from "test/unit/access/AccessControl/Temporal/Data/AccessControlTemporalDataBase.t.sol";
import {AccessControlTemporalModHarness} from "test/utils/harnesses/access/AccessControl/AccessControlTemporalModHarness.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract Data_AccessControlTemporalDataMod_Fuzz_Unit_Test is AccessControlTemporalData_Base_Test {
    AccessControlTemporalModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new AccessControlTemporalModHarness();
        vm.label(address(harness), "AccessControlTemporalModHarness");
    }

    function testFuzz_ShouldReturnZero_GetRoleExpiry_WhenExpiryNotSet(bytes32 role, address account) external view {
        assertEq(harness.getRoleExpiry(role, account), 0, "getRoleExpiry");
    }

    function testFuzz_ShouldReturnStoredExpiry_GetRoleExpiry(bytes32 role, address account, uint256 expiry) external {
        seedRoleExpiry(address(harness), role, account, expiry);

        assertEq(harness.getRoleExpiry(role, account), expiry, "getRoleExpiry");
    }

    function testFuzz_ShouldReturnTrue_IsRoleExpired_WhenNoExpiryAndNoRole(bytes32 role, address account)
        external
        view
    {
        assertEq(harness.isRoleExpired(role, account), true, "isRoleExpired");
    }

    function testFuzz_ShouldReturnFalse_IsRoleExpired_WhenNoExpiryAndRoleExists(bytes32 role, address account)
        external
    {
        seedRole(address(harness), role, account);

        assertEq(harness.isRoleExpired(role, account), false, "isRoleExpired");
    }

    function testFuzz_ShouldReturnFalse_IsRoleExpired_WhenExpiryIsInFuture(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiry = block.timestamp + expiryOffset;
        seedRoleExpiry(address(harness), role, account, expiry);

        assertEq(harness.isRoleExpired(role, account), false, "isRoleExpired");
    }

    function testFuzz_ShouldReturnTrue_IsRoleExpired_WhenTimestampReachesExpiry(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiry = block.timestamp + expiryOffset;
        seedRoleExpiry(address(harness), role, account, expiry);

        vm.warp(expiry);
        assertEq(harness.isRoleExpired(role, account), true, "isRoleExpired");
    }

    function testFuzz_ShouldNotRevert_RequireValidRole_WhenRoleExistsWithoutExpiry(bytes32 role, address account)
        external
    {
        seedRole(address(harness), role, account);

        harness.requireValidRole(role, account);
    }

    function testFuzz_ShouldNotRevert_RequireValidRole_WhenExpiryIsInFuture(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        seedRole(address(harness), role, account);
        seedRoleExpiry(address(harness), role, account, block.timestamp + expiryOffset);

        harness.requireValidRole(role, account);
    }

    function testFuzz_ShouldRevert_RequireValidRole_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", account, role));
        harness.requireValidRole(role, account);
    }

    function testFuzz_ShouldRevert_RequireValidRole_WhenRoleHasExpired(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiry = block.timestamp + expiryOffset;
        seedRole(address(harness), role, account);
        seedRoleExpiry(address(harness), role, account, expiry);

        vm.warp(expiry);
        vm.expectRevert(abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", role, account));
        harness.requireValidRole(role, account);
    }
}
