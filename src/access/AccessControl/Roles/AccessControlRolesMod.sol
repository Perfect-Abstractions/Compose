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

/*
 * @notice Storage slot identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

/**
 * @notice storage struct for the AccessControl.
 * @custom:storage-location erc8042:compose.accesscontrol
 */
struct AccessControlStorage {
    mapping(address account => mapping(bytes32 role => bool hasRole)) hasRole;
    mapping(bytes32 role => bytes32 adminRole) adminRole;
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
 * @notice function to grant a role to an account.
 * @param _role The role to grant.
 * @param _account The account to grant the role to.
 * @return True if the role was granted, false otherwise.
 */
function grantRole(bytes32 _role, address _account) returns (bool) {
    AccessControlStorage storage s = getStorage();
    bytes32 adminRole = s.adminRole[_role];

    if (!s.hasRole[msg.sender][adminRole]) {
        revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
    }

    bool _hasRole = s.hasRole[_account][_role];
    if (!_hasRole) {
        s.hasRole[_account][_role] = true;
        emit RoleGranted(_role, _account, msg.sender);
        return true;
    }
    return false;
}

/**
 * @notice function to revoke a role from an account.
 * @param _role The role to revoke.
 * @param _account The account to revoke the role from.
 * @return True if the role was revoked, false otherwise.
 */
function revokeRole(bytes32 _role, address _account) returns (bool) {
    AccessControlStorage storage s = getStorage();
    bytes32 adminRole = s.adminRole[_role];

    if (!s.hasRole[msg.sender][adminRole]) {
        revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
    }

    bool _hasRole = s.hasRole[_account][_role];
    if (_hasRole) {
        s.hasRole[_account][_role] = false;
        emit RoleRevoked(_role, _account, msg.sender);
        return true;
    }
    return false;
}
