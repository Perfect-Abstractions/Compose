// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlRolesBatchFacet {
    /**
     * @notice Thrown when the account does not have a specific role.
     * @param _role The role that the account does not have.
     * @param _account The account that does not have the role.
     */
    error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

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
     * @notice Storage slot identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

    /**
     * @notice Storage struct for the AccessControl.
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
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.grantRoleBatch.selector,
            this.revokeRoleBatch.selector
        );
    }
}
