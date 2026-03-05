// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlTemporalRevokeFacet {
    /**
     * @notice Event emitted when a temporal role is revoked.
     * @param _role The role that was revoked.
     * @param _account The account from which the role was revoked.
     * @param _sender The account that revoked the role.
     */
    event TemporalRoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

    /**
     * @notice Thrown when the account does not have a specific role.
     * @param _role The role that the account does not have.
     * @param _account The account that does not have the role.
     */
    error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

    /**
     * @notice Storage slot identifier for AccessControl (reused to access roles).
     */
    bytes32 constant ACCESS_CONTROL_STORAGE_POSITION = keccak256("compose.accesscontrol");

    /**
     * @notice Storage struct for AccessControl (reused struct definition).
     * @dev Must match the struct definition in AccessControlDataFacet.
     * @custom:storage-location erc8042:compose.accesscontrol
     */
    struct AccessControlStorage {
        mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
        mapping(bytes32 role => bytes32 adminRole) adminRole;
    }

    /**
     * @notice Storage slot identifier for Temporal functionality.
     */
    bytes32 constant TEMPORAL_STORAGE_POSITION = keccak256("compose.accesscontrol.temporal");

    /**
     * @notice Storage struct for AccessControlTemporal.
     * @custom:storage-location erc8042:compose.accesscontrol.temporal
     */
    struct AccessControlTemporalStorage {
        mapping(address account => mapping(bytes32 role => uint256 expiryTimestamp)) roleExpiry;
    }

    /**
     * @notice Returns the storage for AccessControl.
     * @return s The AccessControl storage struct.
     */
    function getAccessControlStorage() internal pure returns (AccessControlStorage storage s) {
        bytes32 position = ACCESS_CONTROL_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the storage for AccessControlTemporal.
     * @return s The AccessControlTemporal storage struct.
     */
    function getStorage() internal pure returns (AccessControlTemporalStorage storage s) {
        bytes32 position = TEMPORAL_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Revokes a temporal role from an account.
     * @param _role The role to revoke.
     * @param _account The account to revoke the role from.
     * @dev Only the admin of the role can revoke it.
     *      Emits a {TemporalRoleRevoked} event.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function revokeTemporalRole(bytes32 _role, address _account) external {
        AccessControlStorage storage acs = getAccessControlStorage();
        AccessControlTemporalStorage storage s = getStorage();
        bytes32 adminRole = acs.adminRole[_role];

        /**
         * Check if the caller is the admin of the role.
         */
        if (!acs.hasRole[msg.sender][adminRole]) {
            revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
        }

        /**
         * Revoke the role
         */
        bool _hasRole = acs.hasRole[_account][_role];

        /**
         * Only revoke if the role is currently granted
         */
        if (_hasRole) {
            /**
             * Revoke the role from AccessControl storage
             */
            acs.hasRole[_account][_role] = false;

            /**
             * Clear expiry timestamp
             */
            s.roleExpiry[_account][_role] = 0;

            emit TemporalRoleRevoked(_role, _account, msg.sender);
        }
    }

    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.revokeTemporalRole.selector);
    }
}
