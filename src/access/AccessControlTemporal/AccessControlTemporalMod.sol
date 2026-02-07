// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

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

/*
 * @notice Storage slot identifier for AccessControl (reused to access roles).
 */
bytes32 constant ACCESS_CONTROL_STORAGE_POSITION = keccak256("compose.accesscontrol");

/*
 * @notice Storage slot identifier for Temporal functionality.
 */
bytes32 constant TEMPORAL_STORAGE_POSITION = keccak256("compose.accesscontrol.temporal");

/*
 * @notice Storage struct for AccessControl (reused struct definition).
 * @dev Must match the struct definition in AccessControlFacet.
 * @custom:storage-location erc8042:compose.accesscontrol
 */
struct AccessControlStorage {
    mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
    mapping(bytes32 role => bytes32 adminRole) adminRole;
}

/*
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
function getAccessControlStorage() pure returns (AccessControlStorage storage s) {
    bytes32 position = ACCESS_CONTROL_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Returns the storage for AccessControlTemporal.
 * @return s The AccessControlTemporal storage struct.
 */
function getStorage() pure returns (AccessControlTemporalStorage storage s) {
    bytes32 position = TEMPORAL_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice function to get the expiry timestamp for a role assignment.
 * @param _role The role to check.
 * @param _account The account to check.
 * @return The expiry timestamp, or 0 if no expiry is set.
 */
function getRoleExpiry(bytes32 _role, address _account) view returns (uint256) {
    AccessControlTemporalStorage storage s = getStorage();
    return s.roleExpiry[_account][_role];
}

/**
 * @notice function to check if a role assignment has expired.
 * @param _role The role to check.
 * @param _account The account to check.
 * @return True if the role has expired or doesn't exist, false if still valid.
 */
function isRoleExpired(bytes32 _role, address _account) view returns (bool) {
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
 * @notice function to grant a role with an expiry timestamp.
 * @param _role The role to grant.
 * @param _account The account to grant the role to.
 * @param _expiresAt The timestamp when the role should expire.
 * @return True if the role was granted, false otherwise.
 */
function grantRoleWithExpiry(bytes32 _role, address _account, uint256 _expiresAt) returns (bool) {
    AccessControlStorage storage acs = getAccessControlStorage();
    AccessControlTemporalStorage storage s = getStorage();

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

    return true;
}

/**
 * @notice function to revoke a temporal role.
 * @param _role The role to revoke.
 * @param _account The account to revoke the role from.
 * @return True if the role was revoked, false otherwise.
 */
function revokeTemporalRole(bytes32 _role, address _account) returns (bool) {
    AccessControlStorage storage acs = getAccessControlStorage();
    AccessControlTemporalStorage storage s = getStorage();

    bool _hasRole = acs.hasRole[_account][_role];
    if (!_hasRole) {
        return false;
    }

    acs.hasRole[_account][_role] = false;

    /**
     * Clear expiry timestamp only when the role existed
     */
    s.roleExpiry[_account][_role] = 0;

    emit TemporalRoleRevoked(_role, _account, msg.sender);

    return true;
}

/**
 * @notice function to check if an account has a valid (non-expired) role.
 * @param _role The role to check.
 * @param _account The account to check the role for.
 * @custom:error AccessControlUnauthorizedAccount If the account does not have the role.
 * @custom:error AccessControlRoleExpired If the role has expired.
 */
function requireValidRole(bytes32 _role, address _account) view {
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
