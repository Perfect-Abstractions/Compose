// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract CustomDiamond {
    bytes32 constant STORAGE_POSITION = keccak256("compose.deploy.fixture");

    constructor(address[] memory facets) {
        require(facets.length == 2, "Expected exactly the selected facets");
        bytes32 slot = STORAGE_POSITION;
        assembly {
            sstore(slot, mload(facets))
        }
    }

    function facetCount() external view returns (uint256 count) {
        bytes32 slot = STORAGE_POSITION;
        assembly {
            count := sload(slot)
        }
    }
}
