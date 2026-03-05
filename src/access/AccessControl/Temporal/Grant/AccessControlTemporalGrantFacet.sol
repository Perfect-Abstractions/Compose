// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlTemporalGrantFacet {
    /**
     * @notice Event emitted when a role is granted with an expiry timestamp.
     * @param _role The role that was granted.
     * @param _account The account that was granted the role.
     * @param _expiresAt The timestamp when the role expires.
     * @param _sender The account that granted the role.
     */
    event RoleGrantedWithExpiry(
        bytes32 indexed _role, address indexed _account, uint256 _expiresAt, address indexed _sender
    );

    /**
     * @notice Thrown when the account does not have a specific role.
     * @param _role The role that the account does not have.
     * @param _account The account that does not have the role.
     */
    error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

    /**
     * @notice Thrown when a role has expired.
     * @param _role The role that has expired.
     * @param _account The account whose role has expired.
     */
    error AccessControlRoleExpired(bytes32 _role, address _account);

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
     * @notice Grants a role to an account with an expiry timestamp.
     * @param _role The role to grant.
     * @param _account The account to grant the role to.
     * @param _expiresAt The timestamp when the role should expire (must be in the future).
     * @dev Only the admin of the role can grant it with expiry.
     *      Emits a {RoleGrantedWithExpiry} event.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function grantRoleWithExpiry(bytes32 _role, address _account, uint256 _expiresAt) external {
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
         * Require expiry is in the future
         */
        if (_expiresAt <= block.timestamp) {
            revert AccessControlRoleExpired(_role, _account);
        }

        /**
         * Grant the role
         */
        bool _hasRole = acs.hasRole[_account][_role];
        if (!_hasRole) {
            acs.hasRole[_account][_role] = true;
        }

        /**
         * Set expiry timestamp
         */
        s.roleExpiry[_account][_role] = _expiresAt;
        emit RoleGrantedWithExpiry(_role, _account, _expiresAt, msg.sender);
    }

    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.grantRoleWithExpiry.selector);
    }
}
