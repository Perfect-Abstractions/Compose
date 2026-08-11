// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

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

/*
 * @notice Storage slot identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

/*
 * @notice Default admin role.
 */
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

/*
 * @notice Storage slot identifier for Temporal functionality.
 */
bytes32 constant TEMPORAL_STORAGE_POSITION = keccak256("compose.accesscontrol.temporal");

/*
 * @notice Storage slot identifier for Pausable functionality.
 */
bytes32 constant PAUSABLE_STORAGE_POSITION = keccak256("compose.accesscontrol.pausable");

/**
 * @notice storage struct for the AccessControl.
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
 * @return _s The storage for the AccessControl.
 */
function getStorage() pure returns (AccessControlStorage storage _s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        _s.slot := position
    }
}

/**
 * @notice Returns the storage for AccessControlTemporal.
 * @return s The AccessControlTemporal storage struct.
 */
function getTemporalStorage() pure returns (AccessControlTemporalStorage storage s) {
    bytes32 position = TEMPORAL_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Returns the storage for AccessControlPausable.
 * @return s The AccessControlPausable storage struct.
 */
function getPausableStorage() pure returns (AccessControlPausableStorage storage s) {
    bytes32 position = PAUSABLE_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice function to check if an account has a role.
 * @param _role The role to check.
 * @param _account The account to check the role for.
 * @return True if the account has the role, false otherwise.
 */
function hasRole(bytes32 _role, address _account) view returns (bool) {
    AccessControlStorage storage s = getStorage();
    return s.hasRole[_account][_role];
}

/**
 * @notice function to check if an account has a required role that has not expired and is not paused.
 * @param _role The role to assert.
 * @param _account The account to assert the role for.
 * @custom:error AccessControlUnauthorizedAccount If the account does not have the role.
 * @custom:error AccessControlRoleExpired If the account's role has expired.
 * @custom:error AccessControlRolePaused If the role is paused.
 */
function requireRole(bytes32 _role, address _account) view {
    AccessControlStorage storage s = getStorage();
    if (!s.hasRole[_account][_role]) {
        revert AccessControlUnauthorizedAccount(_account, _role);
    }

    AccessControlTemporalStorage storage ts = getTemporalStorage();
    uint256 expiry = ts.roleExpiry[_account][_role];
    if (expiry > 0 && block.timestamp >= expiry) {
        revert AccessControlRoleExpired(_role, _account);
    }

    AccessControlPausableStorage storage ps = getPausableStorage();
    if (ps.pausedRoles[_role]) {
        revert AccessControlRolePaused(_role);
    }
}

/**
 * @notice function to get the admin role for a role.
 * @param _role The role to get the admin for.
 * @return The admin role for the given role.
 */
function getRoleAdmin(bytes32 _role) view returns (bytes32) {
    AccessControlStorage storage s = getStorage();
    return s.adminRole[_role];
}
