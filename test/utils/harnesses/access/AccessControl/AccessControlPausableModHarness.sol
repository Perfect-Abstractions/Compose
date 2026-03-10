// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    isRolePaused as accessControlIsRolePaused,
    pauseRole as accessControlPauseRole,
    unpauseRole as accessControlUnpauseRole,
    requireRoleNotPaused as accessControlRequireRoleNotPaused
} from "src/access/AccessControl/Pausable/AccessControlPausableMod.sol";

contract AccessControlPausableModHarness {
    function isRolePaused(bytes32 role) external view returns (bool) {
        return accessControlIsRolePaused(role);
    }

    function pauseRole(bytes32 role) external {
        accessControlPauseRole(role);
    }

    function unpauseRole(bytes32 role) external {
        accessControlUnpauseRole(role);
    }

    function requireRoleNotPaused(bytes32 role, address account) external view {
        accessControlRequireRoleNotPaused(role, account);
    }
}
