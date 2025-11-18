// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

library LibDiamondQuery {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    function facetAddress(bytes4 selector) internal view returns (address facet) {
        bytes32 pos = DIAMOND_STORAGE_POSITION;
        assembly {
            mstore(0x00, selector)
            mstore(0x20, pos)
            let slot := keccak256(0x00, 0x40)
            facet := and(sload(slot), 0xffffffffffffffffffffffffffffffffffffffff)
        }
    }
}
