/**
 *  SPDX-License-Identifier: MIT
 */
pragma solidity >=0.8.30;

import {LibAccessControl} from "../../../../src/access/AccessControl/LibAccessControl.sol";

/**
 * @title LibAccessControl Test Harness
 * @notice Exposes internal LibAccessControl functions as external for testing
 */
contract LibAccessControlHarness {
    /**
     * @notice Initialize roles for testing
     * @param _account The account to grant the default admin role to
     */
    function initialize(address _account) external {
        LibAccessControl.AccessControlStorage storage s = LibAccessControl.getStorage();
        s.hasRole[_account][LibAccessControl.DEFAULT_ADMIN_ROLE] = true;
    }

    /**
     * @notice Check if an account has a role
     */
    function hasRole(bytes32 _role, address _account) external view returns (bool) {
        return LibAccessControl.hasRole(_role, _account);
    }

    /**
     * @notice Require that an account has a role
     */
    function requireRole(bytes32 _role, address _account) external view {
        LibAccessControl.requireRole(_role, _account);
    }

    /**
     * @notice Set the admin role for a role
     */
    function setRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        LibAccessControl.setRoleAdmin(_role, _adminRole);
    }

    /**
     * @notice Grant a role to an account
     */
    function grantRole(bytes32 _role, address _account) external returns (bool) {
        return LibAccessControl.grantRole(_role, _account);
    }

    /**
     * @notice Revoke a role from an account
     */
    function revokeRole(bytes32 _role, address _account) external returns (bool) {
        return LibAccessControl.revokeRole(_role, _account);
    }

    /**
     * @notice Get the admin role for a role (for testing storage consistency)
     */
    function getRoleAdmin(bytes32 _role) external view returns (bytes32) {
        LibAccessControl.AccessControlStorage storage s = LibAccessControl.getStorage();
        return s.adminRole[_role];
    }

    /**
     * @notice Get raw storage hasRole mapping (for testing storage consistency)
     */
    function getStorageHasRole(address _account, bytes32 _role) external view returns (bool) {
        LibAccessControl.AccessControlStorage storage s = LibAccessControl.getStorage();
        return s.hasRole[_account][_role];
    }

    /**
     * @notice Force set a role without checks (for testing edge cases)
     */
    function forceGrantRole(bytes32 _role, address _account) external {
        LibAccessControl.AccessControlStorage storage s = LibAccessControl.getStorage();
        s.hasRole[_account][_role] = true;
    }

    /**
     * @notice Force revoke a role without checks (for testing edge cases)
     */
    function forceRevokeRole(bytes32 _role, address _account) external {
        LibAccessControl.AccessControlStorage storage s = LibAccessControl.getStorage();
        s.hasRole[_account][_role] = false;
    }

    /**
     * @notice Force set the admin role without checks or events (for testing edge cases)
     */
    function forceSetRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        LibAccessControl.AccessControlStorage storage s = LibAccessControl.getStorage();
        s.adminRole[_role] = _adminRole;
    }

    /**
     * @notice Get the DEFAULT_ADMIN_ROLE constant
     */
    function getDefaultAdminRole() external pure returns (bytes32) {
        return LibAccessControl.DEFAULT_ADMIN_ROLE;
    }
}
