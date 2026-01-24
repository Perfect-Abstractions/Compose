// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlFacet {
    /**
     * @notice Emitted when the admin role for a role is changed.
     * @param _role The role that was changed.
     * @param _previousAdminRole The previous admin role.
     * @param _newAdminRole The new admin role.
     */
    event RoleAdminChanged(bytes32 indexed _role, bytes32 indexed _previousAdminRole, bytes32 indexed _newAdminRole);

    /**
     * @notice Emitted when a role is granted to an account.
     * @param _role The role that was granted.
     * @param _account The account that was granted the role.
     * @param _sender The sender that granted the role.
     */
    event RoleGranted(bytes32 indexed _role, address indexed _account, address indexed _sender);

    /**
     * @notice Emitted when a role is revoked from an account.
     * @param _role The role that was revoked.
     * @param _account The account from which the role was revoked.
     * @param _sender The account that revoked the role.
     */
    event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    /**
     * @notice Thrown when the account does not have a specific role.
     * @param _role The role that the account does not have.
     * @param _account The account that does not have the role.
     */
    error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

    /**
     * @notice Thrown when the sender is not the account to renounce the role from.
     * @param _sender The sender that is not the account to renounce the role from.
     * @param _account The account to renounce the role from.
     */
    error AccessControlUnauthorizedSender(address _sender, address _account);

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
     * @notice Sets the admin role for a role.
     * @param _role The role to set the admin for.
     * @param _adminRole The new admin role to set.
     * @dev Emits a {RoleAdminChanged} event.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the current admin of the role.
     */
    function setRoleAdmin(bytes32 _role, bytes32 _adminRole) external {
        AccessControlStorage storage s = getStorage();
        bytes32 previousAdminRole = s.adminRole[_role];

        /**
         * Check if the caller is the current admin of the role.
         */
        if (!s.hasRole[msg.sender][previousAdminRole]) {
            revert AccessControlUnauthorizedAccount(msg.sender, previousAdminRole);
        }

        s.adminRole[_role] = _adminRole;
        emit RoleAdminChanged(_role, previousAdminRole, _adminRole);
    }

    /**
     * @notice Grants a role to an account.
     * @param _role The role to grant.
     * @param _account The account to grant the role to.
     * @dev Emits a {RoleGranted} event.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function grantRole(bytes32 _role, address _account) external {
        AccessControlStorage storage s = getStorage();
        bytes32 adminRole = s.adminRole[_role];

        /**
         * Check if the caller is the admin of the role.
         */
        if (!s.hasRole[msg.sender][adminRole]) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }

        bool _hasRole = s.hasRole[_account][_role];
        if (!_hasRole) {
            s.hasRole[_account][_role] = true;
            emit RoleGranted(_role, _account, msg.sender);
        }
    }

    /**
     * @notice Revokes a role from an account.
     * @param _role The role to revoke.
     * @param _account The account to revoke the role from.
     * @dev Emits a {RoleRevoked} event.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function revokeRole(bytes32 _role, address _account) external {
        AccessControlStorage storage s = getStorage();
        bytes32 adminRole = s.adminRole[_role];

        /**
         * Check if the caller is the admin of the role.
         */
        if (!s.hasRole[msg.sender][adminRole]) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }

        bool _hasRole = s.hasRole[_account][_role];
        if (_hasRole) {
            s.hasRole[_account][_role] = false;
            emit RoleRevoked(_role, _account, msg.sender);
        }
    }

    /**
     * @notice Grants a role to multiple accounts in a single transaction.
     * @param _role The role to grant.
     * @param _accounts The accounts to grant the role to.
     * @dev Emits a {RoleGranted} event for each newly granted account.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function grantRoleBatch(bytes32 _role, address[] calldata _accounts) external {
        AccessControlStorage storage s = getStorage();
        bytes32 adminRole = s.adminRole[_role];

        /**
         * Check if the caller is the admin of the role.
         */
        if (!s.hasRole[msg.sender][adminRole]) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }

        uint256 length = _accounts.length;
        for (uint256 i = 0; i < length; i++) {
            address account = _accounts[i];
            bool _hasRole = s.hasRole[account][_role];
            if (!_hasRole) {
                s.hasRole[account][_role] = true;
                emit RoleGranted(_role, account, msg.sender);
            }
        }
    }

    /**
     * @notice Revokes a role from multiple accounts in a single transaction.
     * @param _role The role to revoke.
     * @param _accounts The accounts to revoke the role from.
     * @dev Emits a {RoleRevoked} event for each account the role is revoked from.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function revokeRoleBatch(bytes32 _role, address[] calldata _accounts) external {
        AccessControlStorage storage s = getStorage();
        bytes32 adminRole = s.adminRole[_role];

        /**
         * Check if the caller is the admin of the role.
         */
        if (!s.hasRole[msg.sender][adminRole]) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }

        uint256 length = _accounts.length;
        for (uint256 i = 0; i < length; i++) {
            address account = _accounts[i];
            bool _hasRole = s.hasRole[account][_role];
            if (_hasRole) {
                s.hasRole[account][_role] = false;
                emit RoleRevoked(_role, account, msg.sender);
            }
        }
    }

    /**
     * @notice Renounces a role from the caller.
     * @param _role The role to renounce.
     * @param _account The account to renounce the role from.
     * @dev Emits a {RoleRevoked} event.
     * @custom:error AccessControlUnauthorizedSender If the caller is not the account to renounce the role from.
     */
    function renounceRole(bytes32 _role, address _account) external {
        AccessControlStorage storage s = getStorage();

        /**
         * Check If the caller is not the account to renounce the role from.
         */
        if (msg.sender != _account) {
            revert AccessControlUnauthorizedSender(msg.sender, _account);
        }
        bool _hasRole = s.hasRole[_account][_role];
        if (_hasRole) {
            s.hasRole[_account][_role] = false;
            emit RoleRevoked(_role, _account, msg.sender);
        }
    }
}
