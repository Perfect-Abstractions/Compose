// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/access/AccessControlPausable/AccessControlPausableMod.sol" as AccessControlPausable;

/**
 * @title LibAccessControlPausable Test Harness
 * @notice Exposes internal LibAccessControlPausable functions as external for testing
 */
contract AccessControlPausableHarness {
    /**
     * @notice Initialize roles for testing
     * @param _account The account to grant the default admin role to
     */
    function initialize(address _account) external {
        AccessControlPausable.AccessControlStorage storage acs = AccessControlPausable.getAccessControlStorage();
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        acs.hasRole[_account][DEFAULT_ADMIN_ROLE] = true;
    }

    /**
     * @notice Check if a role is paused
     */
    function isRolePaused(bytes32 _role) external view returns (bool) {
        return AccessControlPausable.isRolePaused(_role);
    }

    /**
     * @notice Pause a role
     */
    function pauseRole(bytes32 _role) external {
        AccessControlPausable.pauseRole(_role);
    }

    /**
     * @notice Unpause a role
     */
    function unpauseRole(bytes32 _role) external {
        AccessControlPausable.unpauseRole(_role);
    }

    /**
     * @notice Require that a role is not paused
     */
    function requireRoleNotPaused(bytes32 _role, address _account) external view {
        AccessControlPausable.requireRoleNotPaused(_role, _account);
    }

    /**
     * @notice Force grant a role without any checks (for testing edge cases)
     */
    function forceGrantRole(bytes32 _role, address _account) external {
        AccessControlPausable.AccessControlStorage storage acs = AccessControlPausable.getAccessControlStorage();
        acs.hasRole[_account][_role] = true;
    }

    /**
     * @notice Force set the admin role without checks (for testing edge cases)
     */
    function forceSetRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        AccessControlPausable.AccessControlStorage storage acs = AccessControlPausable.getAccessControlStorage();
        acs.adminRole[_role] = _adminRole;
    }

    /**
     * @notice Get the raw storage pausedRoles value (for testing storage consistency)
     */
    function getStoragePaused(bytes32 _role) external view returns (bool) {
        return AccessControlPausable.getStorage().pausedRoles[_role];
    }
}
