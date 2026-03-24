// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title ERC6909StorageUtils
 * @notice Storage helpers for ERC-6909 tests (layout matches `keccak256("erc6909")`).
 */
library ERC6909StorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant ERC6909_STORAGE_POSITION = keccak256("erc6909");

    function balanceOf(address target, address owner, uint256 id) internal view returns (uint256) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC6909_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(id, ownerSlot));
        return uint256(vm.load(target, slot));
    }

    function allowance(address target, address owner, address spender, uint256 id) internal view returns (uint256) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC6909_STORAGE_POSITION) + 1));
        bytes32 spenderSlot = keccak256(abi.encode(spender, ownerSlot));
        bytes32 slot = keccak256(abi.encode(id, spenderSlot));
        return uint256(vm.load(target, slot));
    }

    function isOperator(address target, address owner, address spender) internal view returns (bool) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC6909_STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(spender, ownerSlot));
        return uint256(vm.load(target, slot)) != 0;
    }

    function setBalanceOf(address target, address owner, uint256 id, uint256 value) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC6909_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(id, ownerSlot));
        vm.store(target, slot, bytes32(value));
    }

    function setAllowance(address target, address owner, address spender, uint256 id, uint256 value) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC6909_STORAGE_POSITION) + 1));
        bytes32 spenderSlot = keccak256(abi.encode(spender, ownerSlot));
        bytes32 slot = keccak256(abi.encode(id, spenderSlot));
        vm.store(target, slot, bytes32(value));
    }

    function setIsOperator(address target, address owner, address spender, bool value) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC6909_STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(spender, ownerSlot));
        vm.store(target, slot, value ? bytes32(uint256(1)) : bytes32(0));
    }
}
