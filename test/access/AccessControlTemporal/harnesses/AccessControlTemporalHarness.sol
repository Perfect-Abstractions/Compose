// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "../../../../src/access/AccessControlTemporal/AccessControlTemporalMod.sol" as AccessControlTemporalMod;

/**
 * @title LibAccessControlTemporal Test Harness
 * @notice Exposes internal LibAccessControlTemporal functions as external for testing
 */
contract AccessControlTemporalHarness {
    /**
     * @notice Initialize roles for testing
     * @param _account The account to grant the default admin role to
     */
    function initialize(address _account) external {
        AccessControlTemporalMod.AccessControlStorage storage acs = AccessControlTemporalMod.getAccessControlStorage();
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        acs.hasRole[_account][DEFAULT_ADMIN_ROLE] = true;
    }

    /**
     * @notice Get the expiry timestamp for a role assignment
     */
    function getRoleExpiry(bytes32 _role, address _account) external view returns (uint256) {
        return AccessControlTemporalMod.getRoleExpiry(_role, _account);
    }

    /**
     * @notice Check if a role assignment has expired
     */
    function isRoleExpired(bytes32 _role, address _account) external view returns (bool) {
        return AccessControlTemporalMod.isRoleExpired(_role, _account);
    }

    /**
     * @notice Grant a role with an expiry timestamp
     */
    function grantRoleWithExpiry(bytes32 _role, address _account, uint256 _expiresAt) external returns (bool) {
        return AccessControlTemporalMod.grantRoleWithExpiry(_role, _account, _expiresAt);
    }

    /**
     * @notice Revoke a temporal role
     */
    function revokeTemporalRole(bytes32 _role, address _account) external returns (bool) {
        return AccessControlTemporalMod.revokeTemporalRole(_role, _account);
    }

    /**
     * @notice Require that an account has a valid (non-expired) role
     */
    function requireValidRole(bytes32 _role, address _account) external view {
        AccessControlTemporalMod.requireValidRole(_role, _account);
    }

    /**
     * @notice Force grant a role without any checks (for testing edge cases)
     */
    function forceGrantRole(bytes32 _role, address _account) external {
        AccessControlTemporalMod.AccessControlStorage storage acs = AccessControlTemporalMod.getAccessControlStorage();
        acs.hasRole[_account][_role] = true;
    }

    /**
     * @notice Force set the admin role without checks (for testing edge cases)
     */
    function forceSetRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        AccessControlTemporalMod.AccessControlStorage storage acs = AccessControlTemporalMod.getAccessControlStorage();
        acs.adminRole[_role] = _adminRole;
    }

    /**
     * @notice Get the raw storage roleExpiry value (for testing storage consistency)
     */
    function getStorageExpiry(address _account, bytes32 _role) external view returns (uint256) {
        return AccessControlTemporalMod.getStorage().roleExpiry[_account][_role];
    }
}
