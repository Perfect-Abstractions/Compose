// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlTemporalDataFacet {
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
     * @notice Returns the expiry timestamp for a role assignment.
     * @param _role The role to check.
     * @param _account The account to check.
     * @return The expiry timestamp, or 0 if no expiry is set.
     */
    function getRoleExpiry(bytes32 _role, address _account) external view returns (uint256) {
        return getStorage().roleExpiry[_account][_role];
    }

    /**
     * @notice Checks if a role assignment has expired.
     * @param _role The role to check.
     * @param _account The account to check.
     * @return True if the role has expired or doesn't exist, false if still valid.
     */
    function isRoleExpired(bytes32 _role, address _account) external view returns (bool) {
        AccessControlStorage storage acs = getAccessControlStorage();
        AccessControlTemporalStorage storage s = getStorage();
        uint256 expiry = s.roleExpiry[_account][_role];

        /**
         * If no expiry set (0), role is valid if account has it
         */
        if (expiry == 0) {
            return !acs.hasRole[_account][_role];
        }

        /**
         * Role is expired if current time is past expiry
         */
        return block.timestamp >= expiry;
    }

    /**
     * @notice Checks if an account has a valid (non-expired) role.
     * @param _role The role to check.
     * @param _account The account to check the role for.
     * @custom:error AccessControlUnauthorizedAccount If the account does not have the role.
     * @custom:error AccessControlRoleExpired If the role has expired.
     */
    function requireValidRole(bytes32 _role, address _account) external view {
        AccessControlStorage storage acs = getAccessControlStorage();
        AccessControlTemporalStorage storage s = getStorage();

        /**
         * Check if account has the role
         */
        if (!acs.hasRole[_account][_role]) {
            revert AccessControlUnauthorizedAccount(_account, _role);
        }

        /**
         * Check if role has expired
         */
        uint256 expiry = s.roleExpiry[_account][_role];
        if (expiry > 0 && block.timestamp >= expiry) {
            revert AccessControlRoleExpired(_role, _account);
        }
    }

    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.getRoleExpiry.selector, this.isRoleExpired.selector, this.requireValidRole.selector);
    }
}
