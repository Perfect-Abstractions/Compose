// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlDataFacet {
    /**
     * @notice Thrown when the account does not have a specific role.
     * @param _role The role that the account does not have.
     * @param _account The account that does not have the role.
     */
    error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

    /**
     * @notice Storage slot identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

    /**
     * @notice Default admin role.
     */
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @notice storage struct for the AccessControl.
     * @custom:storage-location erc8042:compose.accesscontrol
     */
    struct AccessControlStorage {
        mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
        mapping(bytes32 role => bytes32 adminRole) adminRole;
    }

    /**
     * @notice Returns the storage for the AccessControl.
     * @return s The storage for the AccessControl.
     */
    function getStorage() internal pure returns (AccessControlStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns if an account has a role.
     * @param _role The role to check.
     * @param _account The account to check the role for.
     * @return True if the account has the role, false otherwise.
     */
    function hasRole(bytes32 _role, address _account) external view returns (bool) {
        AccessControlStorage storage s = getStorage();
        return s.hasRole[_account][_role];
    }

    /**
     * @notice Checks if an account has a required role.
     * @param _role The role to check.
     * @param _account The account to check the role for.
     * @custom:error AccessControlUnauthorizedAccount If the account does not have the role.
     */
    function requireRole(bytes32 _role, address _account) external view {
        AccessControlStorage storage s = getStorage();
        if (!s.hasRole[_account][_role]) {
            revert AccessControlUnauthorizedAccount(_account, _role);
        }
    }

    /**
     * @notice Returns the admin role for a role.
     * @param _role The role to get the admin for.
     * @return The admin role for the role.
     */
    function getRoleAdmin(bytes32 _role) external view returns (bytes32) {
        AccessControlStorage storage s = getStorage();
        return s.adminRole[_role];
    }

    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.hasRole.selector,
            this.requireRole.selector,
            this.getRoleAdmin.selector
        );
    }
}
