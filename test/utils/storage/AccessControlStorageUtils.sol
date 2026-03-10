// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title AccessControlStorageUtils
 * @notice Storage manipulation utilities for AccessControl-related testing.
 * @dev Uses vm.load and vm.store to directly manipulate split AccessControl storage.
 */
library AccessControlStorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant ACCESS_CONTROL_STORAGE_POSITION = keccak256("compose.accesscontrol");
    bytes32 internal constant PAUSABLE_STORAGE_POSITION = keccak256("compose.accesscontrol.pausable");
    bytes32 internal constant TEMPORAL_STORAGE_POSITION = keccak256("compose.accesscontrol.temporal");

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice AccessControl storage layout (ERC-8042 standard)
     * @custom:storage-location erc8042:compose.accesscontrol
     *
     * Slot 0: mapping(address account => mapping(bytes32 role => bool)) hasRole
     * Slot 1: mapping(bytes32 role => bytes32) adminRole
     *
     * @custom:storage-location erc8042:compose.accesscontrol.pausable
     *
     * Slot 0: mapping(bytes32 role => bool) isRolePaused
     *
     * @custom:storage-location erc8042:compose.accesscontrol.temporal
     *
     * Slot 0: mapping(address account => mapping(bytes32 role => uint256)) roleExpiry
     */

    function hasRole(address target, address account, bytes32 role) internal view returns (bool) {
        bytes32 accountSlot = keccak256(abi.encode(account, uint256(ACCESS_CONTROL_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(role, accountSlot));
        return uint256(vm.load(target, slot)) != 0;
    }

    function adminRole(address target, bytes32 role) internal view returns (bytes32) {
        bytes32 slot = keccak256(abi.encode(role, uint256(ACCESS_CONTROL_STORAGE_POSITION) + 1));
        return vm.load(target, slot);
    }

    function isRolePaused(address target, bytes32 role) internal view returns (bool) {
        bytes32 slot = keccak256(abi.encode(role, uint256(PAUSABLE_STORAGE_POSITION)));
        return uint256(vm.load(target, slot)) != 0;
    }

    function roleExpiry(address target, address account, bytes32 role) internal view returns (uint256) {
        bytes32 accountSlot = keccak256(abi.encode(account, uint256(TEMPORAL_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(role, accountSlot));
        return uint256(vm.load(target, slot));
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    function setHasRole(address target, address account, bytes32 role, bool value) internal {
        bytes32 accountSlot = keccak256(abi.encode(account, uint256(ACCESS_CONTROL_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(role, accountSlot));
        vm.store(target, slot, value ? bytes32(uint256(1)) : bytes32(0));
    }

    function setAdminRole(address target, bytes32 role, bytes32 value) internal {
        bytes32 slot = keccak256(abi.encode(role, uint256(ACCESS_CONTROL_STORAGE_POSITION) + 1));
        vm.store(target, slot, value);
    }

    function setPausedRole(address target, bytes32 role, bool value) internal {
        bytes32 slot = keccak256(abi.encode(role, uint256(PAUSABLE_STORAGE_POSITION)));
        vm.store(target, slot, value ? bytes32(uint256(1)) : bytes32(0));
    }

    function setRoleExpiry(address target, address account, bytes32 role, uint256 expiry) internal {
        bytes32 accountSlot = keccak256(abi.encode(account, uint256(TEMPORAL_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(role, accountSlot));
        vm.store(target, slot, bytes32(expiry));
    }
}
