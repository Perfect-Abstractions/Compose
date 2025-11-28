// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @notice Struct to hold facet address and its function selectors.
struct Facet {
    address facet;
    bytes4[] functionSelectors;
}

library LibDiamondDeploy {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    /// @notice Data stored for each function selector.
    /// @dev Facet address of function selector.
    ///      Position of selector in the 'bytes4[] selectors' array.
    struct FacetAndPosition {
        address facet;
        uint32 position;
    }

    /// @custom:storage-location erc8042:compose.diamond
    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        // Array of all function selectors that can be called in the diamond.
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    error NoBytecodeAtAddress(address _contractAddress, string _message);
    error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);

    function addFacets(Facet[] memory _facets) internal {
        DiamondStorage storage s = getStorage();
        uint32 selectorPosition = uint32(s.selectors.length);
        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i].facet;
            if (facet.code.length == 0) {
                revert NoBytecodeAtAddress(facet, "LibDiamondDeploy: Add facet has no code");
            }
            bytes4[] memory functionSelectors = _facets[i].functionSelectors;
            for (uint256 selectorIndex; selectorIndex < functionSelectors.length; selectorIndex++) {
                bytes4 selector = functionSelectors[selectorIndex];
                address oldFacet = s.facetAndPosition[selector].facet;
                if (oldFacet != address(0)) {
                    revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
                }
                s.facetAndPosition[selector] = FacetAndPosition(facet, selectorPosition);
                s.selectors.push(selector);
                selectorPosition++;
            }
        }
    }
}
