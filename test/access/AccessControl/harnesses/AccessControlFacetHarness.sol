// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {AccessControlFacet} from "../../../../src/access/AccessControl/AccessControlFacet.sol";

/// @title AccessControlFacet Test Harness
/// @notice Extends AccessControlFacet with initialization and test-specific functions
contract AccessControlFacetHarness is AccessControlFacet {
    /// @notice Initialize the DEFAULT_ADMIN_ROLE for testing
    /// @dev This function is only for testing purposes
    function initialize(address _admin) external {
        AccessControlStorage storage s = getStorage();
        s.hasRole[_admin][DEFAULT_ADMIN_ROLE] = true;
    }

    /// @notice Initialize with multiple admins for different roles
    /// @dev This sets up complex role hierarchies for testing
    function initializeWithRoles(address _defaultAdmin, bytes32 _role, address _roleAdmin, bytes32 _roleAdminRole)
        external
    {
        AccessControlStorage storage s = getStorage();
        // Set default admin
        s.hasRole[_defaultAdmin][DEFAULT_ADMIN_ROLE] = true;
        // Set up role hierarchy
        s.adminRole[_role] = _roleAdminRole;
        s.hasRole[_roleAdmin][_roleAdminRole] = true;
    }

    /// @notice Force grant a role without any checks (for testing edge cases)
    /// @dev This bypasses all access control for testing purposes
    function forceGrantRole(bytes32 _role, address _account) external {
        AccessControlStorage storage s = getStorage();
        s.hasRole[_account][_role] = true;
    }

    /// @notice Force revoke a role without any checks (for testing edge cases)
    /// @dev This bypasses all access control for testing purposes
    function forceRevokeRole(bytes32 _role, address _account) external {
        AccessControlStorage storage s = getStorage();
        s.hasRole[_account][_role] = false;
    }

    /// @notice Force set the admin role for a role without any checks
    /// @dev This bypasses all access control for testing purposes
    function forceSetRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        AccessControlStorage storage s = getStorage();
        s.adminRole[_role] = _adminRole;
    }

    /// @notice Get the raw storage hasRole value (for testing storage consistency)
    function getStorageHasRole(address _account, bytes32 _role) external view returns (bool) {
        return getStorage().hasRole[_account][_role];
    }

    /// @notice Get the raw storage adminRole value (for testing storage consistency)
    function getStorageRoleAdmin(bytes32 _role) external view returns (bytes32) {
        return getStorage().adminRole[_role];
    }

    /// @notice Setup a complex role hierarchy for testing
    /// @dev Creates multiple levels of roles with different admins
    function setupComplexRoleHierarchy() external {
        AccessControlStorage storage s = getStorage();

        // Create role hierarchy:
        // DEFAULT_ADMIN_ROLE -> ADMIN_ROLE -> MODERATOR_ROLE -> USER_ROLE
        bytes32 ADMIN_ROLE = keccak256("ADMIN_ROLE");
        bytes32 MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
        bytes32 USER_ROLE = keccak256("USER_ROLE");

        s.adminRole[ADMIN_ROLE] = DEFAULT_ADMIN_ROLE;
        s.adminRole[MODERATOR_ROLE] = ADMIN_ROLE;
        s.adminRole[USER_ROLE] = MODERATOR_ROLE;
    }

    /// @notice Clear all roles for an account (for testing clean state)
    function clearAllRoles(address _account) external {
        AccessControlStorage storage s = getStorage();

        // Clear some common test roles
        s.hasRole[_account][DEFAULT_ADMIN_ROLE] = false;
        s.hasRole[_account][keccak256("ADMIN_ROLE")] = false;
        s.hasRole[_account][keccak256("MODERATOR_ROLE")] = false;
        s.hasRole[_account][keccak256("USER_ROLE")] = false;
        s.hasRole[_account][keccak256("MINTER_ROLE")] = false;
        s.hasRole[_account][keccak256("PAUSER_ROLE")] = false;
    }

    /// @notice Get the DEFAULT_ADMIN_ROLE constant for testing
    function getDefaultAdminRole() external pure returns (bytes32) {
        return DEFAULT_ADMIN_ROLE;
    }

    /// @notice Get the STORAGE_POSITION constant for testing
    function getStoragePosition() external pure returns (bytes32) {
        return STORAGE_POSITION;
    }
}
