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
 * @notice Emitted when a role is revoked from an account.
 * @param _role The role that was revoked.
 * @param _account The account from which the role was revoked.
 * @param _sender The account that revoked the role.
 */
event RoleRevoked(bytes32 indexed _role, address indexed _account, address indexed _sender);

/*
 * @notice Storage slot identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

/*
 * @notice Storage slot identifier for Temporal functionality.
 */
bytes32 constant TEMPORAL_STORAGE_POSITION = keccak256("compose.accesscontrol.temporal");

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
 * @notice function to revoke a role from an account.
 * @param _role The role to revoke.
 * @param _account The account to revoke the role from.
 * @return True if the role was revoked, false otherwise.
 * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
 */
function revokeRole(bytes32 _role, address _account) returns (bool) {
    AccessControlStorage storage s = getStorage();
    bytes32 adminRole = s.adminRole[_role];

    /**
     * Check if the caller is the admin of the role.
     */
    if (!s.hasRole[msg.sender][adminRole]) {
        revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
    }

    AccessControlTemporalStorage storage ts = getTemporalStorage();
    uint256 _expiry = ts.roleExpiry[msg.sender][adminRole];
    if (_expiry > 0 && block.timestamp >= _expiry) {
        revert AccessControlRoleExpired(adminRole, msg.sender);
    }

    bool _hasRole = s.hasRole[_account][_role];
    if (_hasRole) {
        s.hasRole[_account][_role] = false;
        emit RoleRevoked(_role, _account, msg.sender);
        return true;
    }
    return false;
}

