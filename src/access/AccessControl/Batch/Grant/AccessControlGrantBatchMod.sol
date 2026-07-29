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
 * @notice Emitted when a role is granted to an account.
 * @param _role The role that was granted.
 * @param _account The account that was granted the role.
 * @param _sender The sender that granted the role.
 */
event RoleGranted(bytes32 indexed _role, address indexed _account, address indexed _sender);

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
 * @notice function to grant a role to multiple accounts in a single transaction.
 * @param _role The role to grant.
 * @param _accounts The accounts to grant the role to.
 * @dev Emits a {RoleGranted} event for each newly granted account.
 * @custom:error AccessControlUnauthorizedAccount If the caller is not the admin of the role.
 */
function grantRoleBatch(bytes32 _role, address[] calldata _accounts) {
    AccessControlStorage storage s = getStorage();
    bytes32 adminRole = s.adminRole[_role];

    if (!s.hasRole[msg.sender][adminRole]) {
        revert AccessControlUnauthorizedAccount(msg.sender, adminRole);
    }

    AccessControlTemporalStorage storage ts = getTemporalStorage();
    uint256 _expiry = ts.roleExpiry[msg.sender][adminRole];
    if (_expiry > 0 && block.timestamp >= _expiry) {
        revert AccessControlRoleExpired(adminRole, msg.sender);
    }

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

