// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract AccessControlGrantBatchFacet {
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
     * @notice Emitted when a role is granted to an account.
     * @param _role The role that was granted.
     * @param _account The account that was granted the role.
     * @param _sender The sender that granted the role.
     */
    event RoleGranted(bytes32 indexed _role, address indexed _account, address indexed _sender);

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
     * @notice Grants a role to multiple accounts in a single transaction.
     * @param _role The role to grant.
     * @param _accounts The accounts to grant the role to.
     * @dev Emits a {RoleGranted} event for each newly granted account.
     * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
     */
    function grantRoleBatch(bytes32 _role, address[] calldata _accounts) external {
        AccessControlStorage storage s = getStorage();
        bytes32 adminRole = s.adminRole[_role];

        _requireRole(adminRole);

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
     * @notice Exports the selectors that are exposed by the facet.
     * @return Selectors that are exported by the facet.
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.grantRoleBatch.selector);
    }
}

