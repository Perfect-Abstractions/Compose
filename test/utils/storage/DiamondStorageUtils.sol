// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

library DiamondStorageUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("erc8153.diamond");

    function facetNode(address _target, bytes4 _selector)
        internal
        view
        returns (address facet, bytes4 prevFacetNodeId, bytes4 nextFacetNodeId)
    {
        bytes32 slot = keccak256(abi.encode(_selector, DIAMOND_STORAGE_POSITION));
        uint256 word = uint256(vm.load(_target, slot));
        facet = address(uint160(word));
        prevFacetNodeId = bytes4(uint32(word >> 160));
        nextFacetNodeId = bytes4(uint32(word >> 192));
    }

    function facetList(address _target)
        internal
        view
        returns (bytes4 headFacetNodeId, bytes4 tailFacetNodeId, uint32 facetCount, uint32 selectorCount)
    {
        bytes32 slot = bytes32(uint256(DIAMOND_STORAGE_POSITION) + 1);
        uint256 word = uint256(vm.load(_target, slot));
        headFacetNodeId = bytes4(uint32(word));
        tailFacetNodeId = bytes4(uint32(word >> 32));
        facetCount = uint32(word >> 64);
        selectorCount = uint32(word >> 96);
    }
}
