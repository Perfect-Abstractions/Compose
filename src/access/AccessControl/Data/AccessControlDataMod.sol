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

/*
 * @notice Storage slot identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.accesscontrol");

/*
 * @notice Default admin role.
 */
bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;

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
 * @notice function to check if an account has a required role.
 * @param _role The role to assert.
 * @param _account The account to assert the role for.
 * @custom:error AccessControlUnauthorizedAccount If the account does not have the role.
 */
function requireRole(bytes32 _role, address _account) view {
    AccessControlStorage storage s = getStorage();
    if (!s.hasRole[_account][_role]) {
        revert AccessControlUnauthorizedAccount(_account, _role);
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
