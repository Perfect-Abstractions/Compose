// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test, console2} from "forge-std/Test.sol";
import {AccessControlTemporalFacet} from "../../../src/access/AccessControlTemporal/AccessControlTemporalFacet.sol";
import {AccessControlFacet} from "../../../src/access/AccessControl/AccessControlFacet.sol";
import {AccessControlTemporalFacetHarness} from "./harnesses/AccessControlTemporalFacetHarness.sol";
import {AccessControlFacetHarness} from "../AccessControl/harnesses/AccessControlFacetHarness.sol";

contract AccessControlTemporalFacetTest is Test {
    AccessControlTemporalFacetHarness public temporalFacet;
    AccessControlFacetHarness public accessControl;

    /**
     * Test addresses
     */
    address ADMIN = makeAddr("admin");
    address ALICE = makeAddr("alice");
    address BOB = makeAddr("bob");

    /**
     * Test roles
     */
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * Events
     */
    event RoleGrantedWithExpiry(
        bytes32 indexed role, address indexed account, uint256 expiresAt, address indexed sender
    );
    event TemporalRoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    function setUp() public {
        /**
         * Initialize AccessControl first (shared storage)
         */
        accessControl = new AccessControlFacetHarness();
        accessControl.initialize(ADMIN);

        /**
         * Initialize TemporalFacet (uses same AccessControl storage)
         */
        temporalFacet = new AccessControlTemporalFacetHarness();
        temporalFacet.initialize(ADMIN);
    }

    /**
     * ============================================
     * GetRoleExpiry Tests
     * ============================================
     */

    function test_GetRoleExpiry_ReturnsZeroForNonExistentRole() public view {
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), 0);
    }

    function test_GetRoleExpiry_ReturnsExpiryWhenSet() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
        assertEq(temporalFacet.getStorageExpiry(ALICE, MINTER_ROLE), expiry);
    }

    /**
     * ============================================
     * IsRoleExpired Tests
     * ============================================
     */

    function test_IsRoleExpired_ReturnsTrueForNoRole() public view {
        assertTrue(temporalFacet.isRoleExpired(MINTER_ROLE, ALICE));
    }

    function test_IsRoleExpired_ReturnsFalseForFutureExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertFalse(temporalFacet.isRoleExpired(MINTER_ROLE, ALICE));
    }

    function test_IsRoleExpired_ReturnsTrueForPastExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        /**
         * Fast forward past expiry
         */
        vm.warp(expiry + 1);

        assertTrue(temporalFacet.isRoleExpired(MINTER_ROLE, ALICE));
    }

    function test_IsRoleExpired_ReturnsTrueAtExactExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        /**
         * Set time to exactly expiry
         */
        vm.warp(expiry);

        /**
         * At exact expiry time, role should be expired
         */
        assertTrue(temporalFacet.isRoleExpired(MINTER_ROLE, ALICE));
    }

    /**
     * ============================================
     * GrantRoleWithExpiry Tests
     * ============================================
     */

    function test_GrantRoleWithExpiry_SucceedsWithFutureExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.expectEmit(true, true, true, true);
        emit RoleGrantedWithExpiry(MINTER_ROLE, ALICE, expiry, ADMIN);

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
    }

    function test_GrantRoleWithExpiry_CanUpdateExpiry() public {
        uint256 expiry1 = block.timestamp + 7 days;
        uint256 expiry2 = block.timestamp + 14 days;

        vm.startPrank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry1);
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), expiry1);

        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry2);
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), expiry2);
        vm.stopPrank();
    }

    function test_RevertWhen_GrantRoleWithExpiry_PastExpiry() public {
        uint256 pastExpiry = block.timestamp - 1;

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlTemporalFacet.AccessControlRoleExpired.selector, MINTER_ROLE, ALICE)
        );
        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, pastExpiry);
    }

    function test_RevertWhen_GrantRoleWithExpiry_CurrentTimestamp() public {
        uint256 currentTime = block.timestamp;

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlTemporalFacet.AccessControlRoleExpired.selector, MINTER_ROLE, ALICE)
        );
        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, currentTime);
    }

    function test_RevertWhen_GrantRoleWithExpiry_CallerIsNotAdmin() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalFacet.AccessControlUnauthorizedAccount.selector, ALICE, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(ALICE);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, BOB, expiry);
    }

    /**
     * ============================================
     * RevokeTemporalRole Tests
     * ============================================
     */

    function test_RevokeTemporalRole_Succeeds() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.startPrank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), expiry);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit TemporalRoleRevoked(MINTER_ROLE, ALICE, ADMIN);

        vm.prank(ADMIN);
        temporalFacet.revokeTemporalRole(MINTER_ROLE, ALICE);

        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), 0);
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
    }

    function test_RevokeTemporalRole_ClearExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.startPrank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);
        temporalFacet.revokeTemporalRole(MINTER_ROLE, ALICE);
        vm.stopPrank();

        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), 0);
    }

    function test_RevokeTemporalRole_NoExistingRole_DoesNothing() public {
        vm.prank(ADMIN);
        temporalFacet.revokeTemporalRole(MINTER_ROLE, ALICE);

        /**
         * Ensure no state changes
         */
        assertFalse(accessControl.hasRole(MINTER_ROLE, ALICE));
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), 0);
    }

    function test_RevertWhen_RevokeTemporalRole_CallerIsNotAdmin() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalFacet.AccessControlUnauthorizedAccount.selector, BOB, DEFAULT_ADMIN_ROLE
            )
        );
        vm.prank(BOB);
        temporalFacet.revokeTemporalRole(MINTER_ROLE, ALICE);
    }

    /**
     * ============================================
     * RequireValidRole Tests
     * ============================================
     */

    function test_RequireValidRole_PassesWithValidExpiry() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        /**
         * Should not revert
         */
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RequireValidRole_PassesWithoutExpiry() public {
        /**
         * Grant role without expiry using harness (direct storage manipulation)
         */
        temporalFacet.forceGrantRole(MINTER_ROLE, ALICE);

        /**
         * Should not revert (no expiry set means valid)
         */
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireValidRole_Expired() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);

        /**
         * Fast forward past expiry
         */
        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlTemporalFacet.AccessControlRoleExpired.selector, MINTER_ROLE, ALICE)
        );
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RevertWhen_RequireValidRole_NoRole() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalFacet.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE
            )
        );
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_RequireValidRole_AfterRevoke() public {
        uint256 expiry = block.timestamp + 7 days;

        vm.startPrank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, expiry);
        temporalFacet.revokeTemporalRole(MINTER_ROLE, ALICE);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlTemporalFacet.AccessControlUnauthorizedAccount.selector, ALICE, MINTER_ROLE
            )
        );
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }

    /**
     * ============================================
     * Scenario Tests
     * ============================================
     */

    function test_Scenario_TemporaryContractorAccess() public {
        uint256 contractEnd = block.timestamp + 30 days;

        /**
         * Grant contractor role that expires in 30 days
         */
        vm.prank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, contractEnd);

        /**
         * Verify access works now
         */
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);

        /**
         * Fast forward past contract end
         */
        vm.warp(contractEnd + 1);

        /**
         * Access should be denied
         */
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlTemporalFacet.AccessControlRoleExpired.selector, MINTER_ROLE, ALICE)
        );
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }

    function test_Scenario_ExtendExpiryBeforeExpiration() public {
        uint256 initialExpiry = block.timestamp + 7 days;
        uint256 newExpiry = block.timestamp + 14 days;

        vm.startPrank(ADMIN);
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, initialExpiry);
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), initialExpiry);

        /**
         * Extend before expiration
         */
        temporalFacet.grantRoleWithExpiry(MINTER_ROLE, ALICE, newExpiry);
        assertEq(temporalFacet.getRoleExpiry(MINTER_ROLE, ALICE), newExpiry);
        vm.stopPrank();

        /**
         * Access should still work
         */
        temporalFacet.requireValidRole(MINTER_ROLE, ALICE);
    }
}
