// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlPausableFacet} from "../../../../src/access/AccessControlPausable/AccessControlPausableFacet.sol";

/**
 * @title AccessControlPausableFacet Test Harness
 * @notice Extends AccessControlPausableFacet with initialization and test-specific functions
 */
contract AccessControlPausableFacetHarness is AccessControlPausableFacet {
    /**
     * @notice Initialize the DEFAULT_ADMIN_ROLE for testing
     * @dev This function is only for testing purposes
     */
    function initialize(address _admin) external {
        AccessControlStorage storage acs = getAccessControlStorage();
        bytes32 DEFAULT_ADMIN_ROLE = 0x00;
        acs.hasRole[_admin][DEFAULT_ADMIN_ROLE] = true;
    }

    /**
     * @notice Force grant a role without any checks (for testing edge cases)
     * @dev This bypasses all access control for testing purposes
     */
    function forceGrantRole(bytes32 _role, address _account) external {
        AccessControlStorage storage acs = getAccessControlStorage();
        acs.hasRole[_account][_role] = true;
    }

    /**
     * @notice Force set the admin role for a role without any checks
     * @dev This bypasses all access control for testing purposes
     */
    function forceSetRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        AccessControlStorage storage acs = getAccessControlStorage();
        acs.adminRole[_role] = _adminRole;
    }

    /**
     * @notice Get the raw storage pausedRoles value (for testing storage consistency)
     */
    function getStoragePaused(bytes32 _role) external view returns (bool) {
        return getStorage().pausedRoles[_role];
    }
}
