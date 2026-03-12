// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title ERC1155StorageUtils
 * @notice Storage manipulation utilities for ERC1155-related testing.
 * @dev Uses vm.load and vm.store to directly manipulate ERC1155 storage.
 *      Layout matches src/token/ERC1155: keccak256("erc1155") for core data.
 */
library ERC1155StorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant ERC1155_STORAGE_POSITION = keccak256("erc1155");

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice ERC-1155 storage layout (ERC-8042 standard)
     * @custom:storage-location erc8042:erc1155
     *
     * Slot 0: mapping(uint256 id => mapping(address account => uint256)) balanceOf
     * Slot 1: mapping(address account => mapping(address operator => bool)) isApprovedForAll
     */

    function balanceOf(address target, uint256 id, address account) internal view returns (uint256) {
        bytes32 idSlot = keccak256(abi.encode(id, uint256(ERC1155_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(account, idSlot));
        return uint256(vm.load(target, slot));
    }

    function isApprovedForAll(address target, address account, address operator) internal view returns (bool) {
        bytes32 accountSlot = keccak256(abi.encode(account, uint256(ERC1155_STORAGE_POSITION) + 1));
        bytes32 slot = keccak256(abi.encode(operator, accountSlot));
        return uint256(vm.load(target, slot)) != 0;
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    function setBalanceOf(address target, uint256 id, address account, uint256 value) internal {
        bytes32 idSlot = keccak256(abi.encode(id, uint256(ERC1155_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(account, idSlot));
        vm.store(target, slot, bytes32(value));
    }

    function setApprovedForAll(address target, address account, address operator, bool value) internal {
        bytes32 accountSlot = keccak256(abi.encode(account, uint256(ERC1155_STORAGE_POSITION) + 1));
        bytes32 slot = keccak256(abi.encode(operator, accountSlot));
        vm.store(target, slot, value ? bytes32(uint256(1)) : bytes32(0));
    }
}
