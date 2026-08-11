// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    DEFAULT_ADMIN_ROLE,
    hasRole as accessControlHasRole,
    requireRole as accessControlRequireRole
} from "src/access/AccessControl/Data/AccessControlDataMod.sol";
import {setRoleAdmin as accessControlSetRoleAdmin} from "src/access/AccessControl/Admin/AccessControlAdminMod.sol";
import {getRoleAdmin as accessControlGetRoleAdmin} from "src/access/AccessControl/Data/AccessControlDataMod.sol";
import {grantRole as accessControlGrantRole} from "src/access/AccessControl/Grant/AccessControlGrantMod.sol";
import {revokeRole as accessControlRevokeRole} from "src/access/AccessControl/Revoke/AccessControlRevokeMod.sol";
import {
    renounceRole as accessControlRenounceRole
} from "src/access/AccessControl/Renounce/AccessControlRenounceMod.sol";
import {
    grantRoleBatch as accessControlGrantRoleBatch
} from "src/access/AccessControl/Batch/Grant/AccessControlGrantBatchMod.sol";
import {
    revokeRoleBatch as accessControlRevokeRoleBatch
} from "src/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchMod.sol";
import {
    getRoleExpiry as accessControlGetRoleExpiry,
    isRoleExpired as accessControlIsRoleExpired,
    requireValidRole as accessControlRequireValidRole
} from "src/access/AccessControl/Temporal/Data/AccessControlTemporalDataMod.sol";
import {
    grantRoleWithExpiry as accessControlGrantRoleWithExpiry
} from "src/access/AccessControl/Temporal/Grant/AccessControlTemporalGrantMod.sol";
import {
    isRolePaused as accessControlIsRolePaused,
    pauseRole as accessControlPauseRole,
    unpauseRole as accessControlUnpauseRole
} from "src/access/AccessControl/Pausable/AccessControlPausableMod.sol";

contract AccessControlCombinedModHarness {
    function DEFAULT_ADMIN_ROLE_VALUE() external pure returns (bytes32) {
        return DEFAULT_ADMIN_ROLE;
    }

    function hasRole(bytes32 role, address account) external view returns (bool) {
        return accessControlHasRole(role, account);
    }

    function requireRole(bytes32 role, address account) external view {
        accessControlRequireRole(role, account);
    }

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external {
        accessControlSetRoleAdmin(role, adminRole);
    }

    function adminRole(bytes32 role) external view returns (bytes32) {
        return accessControlGetRoleAdmin(role);
    }

    function grantRole(bytes32 role, address account) external returns (bool) {
        return accessControlGrantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) external returns (bool) {
        return accessControlRevokeRole(role, account);
    }

    function renounceRole(bytes32 role, address account) external {
        accessControlRenounceRole(role, account);
    }

    function grantRoleBatch(bytes32 role, address[] calldata accounts) external {
        accessControlGrantRoleBatch(role, accounts);
    }

    function revokeRoleBatch(bytes32 role, address[] calldata accounts) external {
        accessControlRevokeRoleBatch(role, accounts);
    }

    function getRoleExpiry(bytes32 role, address account) external view returns (uint256) {
        return accessControlGetRoleExpiry(role, account);
    }

    function isRoleExpired(bytes32 role, address account) external view returns (bool) {
        return accessControlIsRoleExpired(role, account);
    }

    function requireValidRole(bytes32 role, address account) external view {
        accessControlRequireValidRole(role, account);
    }

    function grantRoleWithExpiry(bytes32 role, address account, uint256 expiresAt) external {
        accessControlGrantRoleWithExpiry(role, account, expiresAt);
    }

    function isRolePaused(bytes32 role) external view returns (bool) {
        return accessControlIsRolePaused(role);
    }

    function pauseRole(bytes32 role) external {
        accessControlPauseRole(role);
    }

    function unpauseRole(bytes32 role) external {
        accessControlUnpauseRole(role);
    }
}
