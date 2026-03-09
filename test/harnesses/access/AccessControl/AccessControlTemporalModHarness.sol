// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    getRoleExpiry as accessControlGetRoleExpiry,
    isRoleExpired as accessControlIsRoleExpired,
    requireValidRole as accessControlRequireValidRole
} from "src/access/AccessControl/Temporal/Data/AccessControlTemporalDataMod.sol";
import {
    grantRoleWithExpiry as accessControlGrantRoleWithExpiry
} from "src/access/AccessControl/Temporal/Grant/AccessControlTemporalGrantMod.sol";
import {
    revokeTemporalRole as accessControlRevokeTemporalRole
} from "src/access/AccessControl/Temporal/Revoke/AccessControlTemporalRevokeMod.sol";

contract AccessControlTemporalModHarness {
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

    function revokeTemporalRole(bytes32 role, address account) external {
        accessControlRevokeTemporalRole(role, account);
    }
}
