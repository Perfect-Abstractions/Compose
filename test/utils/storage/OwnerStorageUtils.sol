// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title OwnerStorageUtils
 * @notice Storage manipulation utilities for Owner-related testing.
 * @dev Uses vm.load and vm.store to directly manipulate Owner storage.
 *      Slots match src/access/Owner: erc173.owner and erc173.owner.pending.
 */
library OwnerStorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant OWNER_STORAGE_POSITION = keccak256("erc173.owner");
    bytes32 internal constant PENDING_OWNER_STORAGE_POSITION = keccak256("erc173.owner.pending");

    function owner(address target) internal view returns (address) {
        return address(uint160(uint256(vm.load(target, OWNER_STORAGE_POSITION))));
    }

    function pendingOwner(address target) internal view returns (address) {
        return address(uint160(uint256(vm.load(target, PENDING_OWNER_STORAGE_POSITION))));
    }

    function setOwner(address target, address value) internal {
        vm.store(target, OWNER_STORAGE_POSITION, bytes32(uint256(uint160(value))));
    }

    function setPendingOwner(address target, address value) internal {
        vm.store(target, PENDING_OWNER_STORAGE_POSITION, bytes32(uint256(uint160(value))));
    }
}
