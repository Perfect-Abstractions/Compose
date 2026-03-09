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
import {grantRole as accessControlGrantRole} from "src/access/AccessControl/Grant/AccessControlGrantMod.sol";
import {revokeRole as accessControlRevokeRole} from "src/access/AccessControl/Revoke/AccessControlRevokeMod.sol";
import {renounceRole as accessControlRenounceRole} from "src/access/AccessControl/Renounce/AccessControlRenounceMod.sol";
import {grantRoleBatch as accessControlGrantRoleBatch} from "src/access/AccessControl/Batch/Grant/AccessControlGrantBatchMod.sol";
import {revokeRoleBatch as accessControlRevokeRoleBatch} from "src/access/AccessControl/Batch/Revoke/AccessControlRevokeBatchMod.sol";

contract AccessControlCoreModHarness {
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
}
