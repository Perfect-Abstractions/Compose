// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @notice Event emitted when a role is paused.
 * @param _role The role that was paused.
 * @param _account The account that paused the role.
 */
event RolePaused(bytes32 indexed _role, address indexed _account);

/**
 * @notice Event emitted when a role is unpaused.
 * @param _role The role that was unpaused.
 * @param _account The account that unpaused the role.
 */
event RoleUnpaused(bytes32 indexed _role, address indexed _account);

/**
 * @notice Thrown when the account does not have a specific role.
 * @param _role The role that the account does not have.
 * @param _account The account that does not have the role.
 */
error AccessControlUnauthorizedAccount(address _account, bytes32 _role);

/**
 * @notice Thrown when a role is paused and an operation requiring that role is attempted.
 * @param _role The role that is paused.
 */
error AccessControlRolePaused(bytes32 _role);

/*
 * @notice Storage slot identifier for AccessControl (reused to access roles).
 */
bytes32 constant ACCESS_CONTROL_STORAGE_POSITION = keccak256("compose.accesscontrol");

/*
 * @notice Storage slot identifier for Pausable functionality.
 */
bytes32 constant PAUSABLE_STORAGE_POSITION = keccak256("compose.accesscontrol.pausable");

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
 * @notice Storage struct for AccessControlPausable.
 * @custom:storage-location erc8042:compose.accesscontrol.pausable
 */
struct AccessControlPausableStorage {
    mapping(bytes32 role => bool paused) pausedRoles;
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
 * @notice Returns the storage for AccessControlPausable.
 * @return s The AccessControlPausable storage struct.
 */
function getStorage() pure returns (AccessControlPausableStorage storage s) {
    bytes32 position = PAUSABLE_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice function to check if a role is paused.
 * @param _role The role to check.
 * @return True if the role is paused, false otherwise.
 */
function isRolePaused(bytes32 _role) view returns (bool) {
    AccessControlPausableStorage storage s = getStorage();
    return s.pausedRoles[_role];
}

/**
 * @notice function to pause a role.
 * @param _role The role to pause.
 */
function pauseRole(bytes32 _role) {
    AccessControlPausableStorage storage s = getStorage();
    s.pausedRoles[_role] = true;
    emit RolePaused(_role, msg.sender);
}

/**
 * @notice function to unpause a role.
 * @param _role The role to unpause.
 */
function unpauseRole(bytes32 _role) {
    AccessControlPausableStorage storage s = getStorage();
    s.pausedRoles[_role] = false;
    emit RoleUnpaused(_role, msg.sender);
}

/**
 * @notice function to check if an account has a role and if the role is not paused.
 * @param _role The role to check.
 * @param _account The account to check the role for.
 * @custom:error AccessControlUnauthorizedAccount If the account does not have the role.
 * @custom:error AccessControlRolePaused If the role is paused.
 */
function requireRoleNotPaused(bytes32 _role, address _account) view {
    AccessControlStorage storage acs = getAccessControlStorage();
    AccessControlPausableStorage storage s = getStorage();

    /**
     * First check if the account has the role
     */
    if (!acs.hasRole[_account][_role]) {
        revert AccessControlUnauthorizedAccount(_account, _role);
    }

    /**
     * Then check if the role is paused
     */
    if (s.pausedRoles[_role]) {
        revert AccessControlRolePaused(_role);
    }
}
