// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title ERC721StorageUtils
 * @notice Storage manipulation utilities for ERC721 token testing
 * @dev Uses vm.load and vm.store to directly manipulate storage slots
 */
library ERC721StorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant STORAGE_POSITION = keccak256("erc721");

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice ERC-721 storage layout (ERC-8042 standard)
     * @custom:storage-location erc8042:erc721
     *
     * Slot 0: mapping(uint256 tokenId => address owner) ownerOf
     * Slot 1: mapping(address owner => uint256 balance) balanceOf
     * Slot 2: mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll
     * Slot 3: mapping(uint256 tokenId => address approved) approved
     */

    function ownerOf(address target, uint256 tokenId) internal view returns (address) {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(STORAGE_POSITION)));
        return address(uint160(uint256(vm.load(target, slot))));
    }

    function balanceOf(address target, address owner) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION) + 1));
        return uint256(vm.load(target, slot));
    }

    function isApprovedForAll(address target, address owner, address operator) internal view returns (bool) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(operator, ownerSlot));
        return uint256(vm.load(target, slot)) != 0;
    }

    function getApproved(address target, uint256 tokenId) internal view returns (address) {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(STORAGE_POSITION) + 3));
        return address(uint160(uint256(vm.load(target, slot))));
    }

    /*//////////////////////////////////////////////////////////////
                                SETTERS
    //////////////////////////////////////////////////////////////*/

    function setOwnerOf(address target, uint256 tokenId, address owner) internal {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(STORAGE_POSITION)));
        vm.store(target, slot, bytes32(uint256(uint160(owner))));
    }

    function setBalanceOf(address target, address owner, uint256 balance) internal {
        bytes32 slot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION) + 1));
        vm.store(target, slot, bytes32(balance));
    }

    function setApprovalForAll(address target, address owner, address operator, bool approved) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(operator, ownerSlot));
        vm.store(target, slot, bytes32(uint256(approved ? 1 : 0)));
    }

    function setApproved(address target, uint256 tokenId, address approved) internal {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(STORAGE_POSITION) + 3));
        vm.store(target, slot, bytes32(uint256(uint160(approved))));
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Mint a token by setting owner and incrementing balance
     */
    function mint(address target, address to, uint256 tokenId) internal {
        setOwnerOf(target, tokenId, to);
        uint256 currentBalance = balanceOf(target, to);
        setBalanceOf(target, to, currentBalance + 1);
    }

    /**
     * @notice Burn a token by clearing owner and decrementing balance
     */
    function burn(address target, uint256 tokenId) internal {
        address owner = ownerOf(target, tokenId);
        uint256 currentBalance = balanceOf(target, owner);
        setOwnerOf(target, tokenId, address(0));
        setBalanceOf(target, owner, currentBalance - 1);
        setApproved(target, tokenId, address(0));
    }
}
