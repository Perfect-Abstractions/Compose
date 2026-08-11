// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlAdminFacet {
    /**
     * @notice Emitted when the admin role for a role is changed.
     * @param _role The role that was changed.
     * @param _previousAdminRole The previous admin role.
     * @param _newAdminRole The new admin role.
     */
    event RoleAdminChanged(bytes32 indexed _role, bytes32 indexed _previousAdminRole, bytes32 indexed _newAdminRole);

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
     * @notice Thrown when a role is paused and an operation requiring that role is attempted.
     * @param _role The role that is paused.
     */
    error AccessControlRolePaused(bytes32 _role);

    /**
     * @notice Storage slot identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

    /**
     * @notice Storage slot identifier for Temporal functionality.
     */
    bytes32 constant TEMPORAL_STORAGE_POSITION = keccak256("compose.accesscontrol.temporal");

    /**
     * @notice Storage slot identifier for Pausable functionality.
     */
    bytes32 constant PAUSABLE_STORAGE_POSITION = keccak256("compose.accesscontrol.pausable");

    /**
     * @notice Storage struct for the AccessControl.
     * @custom:storage-location erc8042:compose.accesscontrol
     */
    struct AccessControlStorage {
        mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
        mapping(bytes32 role => bytes32 adminRole) adminRole;
    }

    /**
     * @notice Storage struct for AccessControlTemporal.
     * @custom:storage-location erc8042:compose.accesscontrol.temporal
     */
    struct AccessControlTemporalStorage {
        mapping(address account => mapping(bytes32 role => uint256 expiryTimestamp)) roleExpiry;
    }

    /**
     * @notice Storage struct for AccessControlPausable.
     * @custom:storage-location erc8042:compose.accesscontrol.pausable
     */
    struct AccessControlPausableStorage {
        mapping(bytes32 role => bool paused) pausedRoles;
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
     * @notice Returns the storage for AccessControlTemporal.
     * @return s The AccessControlTemporal storage struct.
     */
    function getTemporalStorage() internal pure returns (AccessControlTemporalStorage storage s) {
        bytes32 position = TEMPORAL_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the storage for AccessControlPausable.
     * @return s The AccessControlPausable storage struct.
     */
    function getPausableStorage() internal pure returns (AccessControlPausableStorage storage s) {
        bytes32 position = PAUSABLE_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Requires the caller to have a specific role that has not expired and is not paused.
     * @param _role The role that the caller must have.
     * @dev Reverts with {AccessControlUnauthorizedAccount} if the caller does not have the role.
     * @dev Reverts with {AccessControlRoleExpired} if the caller's role has expired.
     * @dev Reverts with {AccessControlRolePaused} if the role is paused.
     */
    function _requireRole(bytes32 _role) internal view {
        AccessControlStorage storage s = getStorage();

        if (!s.hasRole[msg.sender][_role]) {
            revert AccessControlUnauthorizedAccount(msg.sender, _role);
        }

        AccessControlTemporalStorage storage ts = getTemporalStorage();
        uint256 expiry = ts.roleExpiry[msg.sender][_role];
        if (expiry > 0 && block.timestamp >= expiry) {
            revert AccessControlRoleExpired(_role, msg.sender);
        }

        AccessControlPausableStorage storage ps = getPausableStorage();
        if (ps.pausedRoles[_role]) {
            revert AccessControlRolePaused(_role);
        }
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

        _requireRole(previousAdminRole);

        s.adminRole[_role] = _adminRole;
        emit RoleAdminChanged(_role, previousAdminRole, _adminRole);
    }

    /**
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.setRoleAdmin.selector);
    }
}
