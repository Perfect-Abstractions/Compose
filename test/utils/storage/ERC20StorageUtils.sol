// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title ERC20StorageUtils
 * @notice Storage manipulation utilities for ERC20 token testing
 * @dev Uses vm.load and vm.store to directly manipulate storage slots
 */
library ERC20StorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant STORAGE_POSITION = keccak256("erc20");

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice ERC-20 Transfer storage layout (ERC-8042 standard)
     * @custom:storage-location erc8042:compose.erc20.transfer
     *
     * Slot 0: mapping(address owner => uint256 balance) balanceOf
     * Slot 1: uint256 totalSupply
     * Slot 2: mapping(address owner => mapping(address spender => uint256)) allowance
     */

    function balanceOf(address target, address owner) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION)));
        return uint256(vm.load(target, slot));
    }

    function totalSupply(address target) internal view returns (uint256) {
        bytes32 slot = bytes32(uint256(STORAGE_POSITION) + 1);
        return uint256(vm.load(target, slot));
    }

    function allowance(address target, address owner, address spender) internal view returns (uint256) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(spender, ownerSlot));
        return uint256(vm.load(target, slot));
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    function setBalance(address target, address owner, uint256 balance) internal {
        bytes32 slot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION)));
        vm.store(target, slot, bytes32(balance));
    }

    function setTotalSupply(address target, uint256 supply) internal {
        bytes32 slot = bytes32(uint256(STORAGE_POSITION) + 1);
        vm.store(target, slot, bytes32(supply));
    }

    function setAllowance(address target, address owner, address spender, uint256 amount) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(spender, ownerSlot));
        vm.store(target, slot, bytes32(amount));
    }

    /**
     * @notice Mint tokens by updating balance and totalSupply
     */
    function mint(address target, address to, uint256 amount) internal {
        uint256 currentBalance = balanceOf(target, to);
        uint256 currentSupply = totalSupply(target);

        setBalance(target, to, currentBalance + amount);
        setTotalSupply(target, currentSupply + amount);
    }
}
