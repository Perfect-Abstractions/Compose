// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

/**
 * @title ERC721StorageUtils
 * @notice Storage manipulation utilities for ERC-721-related testing.
 * @dev Uses vm.load and vm.store to directly manipulate ERC-721 storage.
 *      Layout matches src/token/ERC721:
 *      - keccak256("erc721") for core ownership/approval data
 *      - keccak256("erc721.enumerable") for enumerable data
 */
library ERC721StorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 internal constant ERC721_STORAGE_POSITION = keccak256("erc721");
    bytes32 internal constant ERC721_ENUMERABLE_STORAGE_POSITION = keccak256("erc721.enumerable");

    /*//////////////////////////////////////////////////////////////
                                CORE ERC-721
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice ERC-721 core storage layout (matches ERC721DataFacet)
     * @custom:storage-location erc8042:erc721
     *
     * Slot 0: mapping(uint256 tokenId => address owner) ownerOf
     * Slot 1: mapping(address owner => uint256 balance) balanceOf
     * Slot 2: mapping(address owner => mapping(address operator => bool)) isApprovedForAll
     * Slot 3: mapping(uint256 tokenId => address approved) approved
     */

    function ownerOf(address target, uint256 tokenId) internal view returns (address) {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_STORAGE_POSITION)));
        return address(uint160(uint256(vm.load(target, slot))));
    }

    function balanceOf(address target, address owner) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(owner, uint256(ERC721_STORAGE_POSITION) + 1));
        return uint256(vm.load(target, slot));
    }

    function isApprovedForAll(address target, address owner, address operator) internal view returns (bool) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC721_STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(operator, ownerSlot));
        return uint256(vm.load(target, slot)) != 0;
    }

    function getApproved(address target, uint256 tokenId) internal view returns (address) {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_STORAGE_POSITION) + 3));
        return address(uint160(uint256(vm.load(target, slot))));
    }

    function setOwnerOf(address target, uint256 tokenId, address owner) internal {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_STORAGE_POSITION)));
        vm.store(target, slot, bytes32(uint256(uint160(owner))));
    }

    function setBalanceOf(address target, address owner, uint256 balance) internal {
        bytes32 slot = keccak256(abi.encode(owner, uint256(ERC721_STORAGE_POSITION) + 1));
        vm.store(target, slot, bytes32(balance));
    }

    function setApprovedForAll(address target, address owner, address operator, bool approved) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC721_STORAGE_POSITION) + 2));
        bytes32 slot = keccak256(abi.encode(operator, ownerSlot));
        vm.store(target, slot, approved ? bytes32(uint256(1)) : bytes32(0));
    }

    function setApproved(address target, uint256 tokenId, address spender) internal {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_STORAGE_POSITION) + 3));
        vm.store(target, slot, bytes32(uint256(uint160(spender))));
    }

    /**
     * @notice Helper to mint a token by updating owner and balances.
     */
    function mint(address target, address to, uint256 tokenId) internal {
        setOwnerOf(target, tokenId, to);

        uint256 currentBalance = balanceOf(target, to);
        setBalanceOf(target, to, currentBalance + 1);
    }

    /**
     * @notice Helper to burn a token by clearing owner and updating balances.
     */
    function burn(address target, uint256 tokenId) internal {
        address owner = ownerOf(target, tokenId);
        setOwnerOf(target, tokenId, address(0));

        uint256 currentBalance = balanceOf(target, owner);
        setBalanceOf(target, owner, currentBalance - 1);

        // Clear single-token approval
        setApproved(target, tokenId, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                           ENUMERABLE EXTENSION
    //////////////////////////////////////////////////////////////*/

    /*
     * @notice ERC-721 enumerable storage layout (matches ERC721EnumerableDataFacet and mods)
     * @custom:storage-location erc8042:erc721.enumerable
     *
     * Slot 0: mapping(address owner => mapping(uint256 index => uint256 tokenId)) ownerTokens
     * Slot 1: mapping(uint256 tokenId => uint256 ownerTokensIndex) ownerTokensIndex
     * Slot 2: uint256[] allTokens
     * Slot 3: mapping(uint256 tokenId => uint256 allTokensIndex) allTokensIndex
     *
     * Note: ERC721EnumerableDataFacet currently only uses ownerTokens and allTokens length;
     *       transfer/mint/burn enumerable mods use the index mappings as well.
     */

    function ownerTokenByIndex(address target, address owner, uint256 index) internal view returns (uint256) {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC721_ENUMERABLE_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(index, ownerSlot));
        return uint256(vm.load(target, slot));
    }

    function ownerTokensIndex(address target, uint256 tokenId) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 1));
        return uint256(vm.load(target, slot));
    }

    function allTokensLength(address target) internal view returns (uint256) {
        // Dynamic array length is stored at the base slot
        bytes32 slot = bytes32(uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 2);
        return uint256(vm.load(target, slot));
    }

    function allTokensIndex(address target, uint256 tokenId) internal view returns (uint256) {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 3));
        return uint256(vm.load(target, slot));
    }

    function setOwnerTokenByIndex(address target, address owner, uint256 index, uint256 tokenId) internal {
        bytes32 ownerSlot = keccak256(abi.encode(owner, uint256(ERC721_ENUMERABLE_STORAGE_POSITION)));
        bytes32 slot = keccak256(abi.encode(index, ownerSlot));
        vm.store(target, slot, bytes32(tokenId));
    }

    function setOwnerTokensIndex(address target, uint256 tokenId, uint256 index) internal {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 1));
        vm.store(target, slot, bytes32(index));
    }

    function pushAllToken(address target, uint256 tokenId) internal {
        uint256 length = allTokensLength(target);

        // Dynamic array layout:
        // - length stored at slot `p`
        // - elements stored starting at slot `keccak256(abi.encode(p)) + index`
        bytes32 arraySlot = bytes32(uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 2);
        bytes32 baseSlot = keccak256(abi.encode(arraySlot));
        bytes32 elementSlot = bytes32(uint256(baseSlot) + length);

        vm.store(target, elementSlot, bytes32(tokenId));
        vm.store(target, arraySlot, bytes32(length + 1));

        // Track index
        bytes32 indexSlot = keccak256(abi.encode(tokenId, uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 3));
        vm.store(target, indexSlot, bytes32(length));
    }

    function setAllTokensIndex(address target, uint256 tokenId, uint256 index) internal {
        bytes32 slot = keccak256(abi.encode(tokenId, uint256(ERC721_ENUMERABLE_STORAGE_POSITION) + 3));
        vm.store(target, slot, bytes32(index));
    }
}

