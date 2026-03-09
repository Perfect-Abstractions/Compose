// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    AccessControlTemporalData_Base_Test
} from "test/unit/access/AccessControl/Temporal/Data/AccessControlTemporalDataBase.t.sol";
import {
    AccessControlTemporalDataFacet
} from "src/access/AccessControl/Temporal/Data/AccessControlTemporalDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/AccessControl.tree
 */
contract Data_AccessControlTemporalDataFacet_Fuzz_Unit_Test is AccessControlTemporalData_Base_Test {
    AccessControlTemporalDataFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new AccessControlTemporalDataFacet();
        vm.label(address(facet), "AccessControlTemporalDataFacet");
    }

    function testFuzz_ShouldReturnZero_GetRoleExpiry_WhenExpiryNotSet(bytes32 role, address account) external view {
        assertEq(facet.getRoleExpiry(role, account), 0, "getRoleExpiry");
    }

    function testFuzz_ShouldReturnStoredExpiry_GetRoleExpiry(bytes32 role, address account, uint256 expiry) external {
        seedRoleExpiry(address(facet), role, account, expiry);

        assertEq(facet.getRoleExpiry(role, account), expiry, "getRoleExpiry");
    }

    function testFuzz_ShouldReturnTrue_IsRoleExpired_WhenNoExpiryAndNoRole(bytes32 role, address account)
        external
        view
    {
        assertEq(facet.isRoleExpired(role, account), true, "isRoleExpired");
    }

    function testFuzz_ShouldReturnFalse_IsRoleExpired_WhenNoExpiryAndRoleExists(bytes32 role, address account)
        external
    {
        seedRole(address(facet), role, account);

        assertEq(facet.isRoleExpired(role, account), false, "isRoleExpired");
    }

    function testFuzz_ShouldReturnFalse_IsRoleExpired_WhenExpiryIsInFuture(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiry = block.timestamp + expiryOffset;
        seedRoleExpiry(address(facet), role, account, expiry);

        assertEq(facet.isRoleExpired(role, account), false, "isRoleExpired");
    }

    function testFuzz_ShouldReturnTrue_IsRoleExpired_WhenTimestampReachesExpiry(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiry = block.timestamp + expiryOffset;
        seedRoleExpiry(address(facet), role, account, expiry);

        vm.warp(expiry);
        assertEq(facet.isRoleExpired(role, account), true, "isRoleExpired");
    }

    function testFuzz_ShouldNotRevert_RequireValidRole_WhenRoleExistsWithoutExpiry(bytes32 role, address account)
        external
    {
        seedRole(address(facet), role, account);

        facet.requireValidRole(role, account);
    }

    function testFuzz_ShouldNotRevert_RequireValidRole_WhenExpiryIsInFuture(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        seedRole(address(facet), role, account);
        seedRoleExpiry(address(facet), role, account, block.timestamp + expiryOffset);

        facet.requireValidRole(role, account);
    }

    function testFuzz_ShouldRevert_RequireValidRole_WhenAccountDoesNotHaveRole(bytes32 role, address account) external {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalDataFacet.AccessControlUnauthorizedAccount.selector, account, role
            )
        );
        facet.requireValidRole(role, account);
    }

    function testFuzz_ShouldRevert_RequireValidRole_WhenRoleHasExpired(
        bytes32 role,
        address account,
        uint256 expiryOffset
    ) external {
        vm.assume(expiryOffset > 0);
        vm.assume(expiryOffset < 365 days);

        uint256 expiry = block.timestamp + expiryOffset;
        seedRole(address(facet), role, account);
        seedRoleExpiry(address(facet), role, account, expiry);

        vm.warp(expiry);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlTemporalDataFacet.AccessControlRoleExpired.selector, role, account)
        );
        facet.requireValidRole(role, account);
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            AccessControlTemporalDataFacet.getRoleExpiry.selector,
            AccessControlTemporalDataFacet.isRoleExpired.selector,
            AccessControlTemporalDataFacet.requireValidRole.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
