// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title Two-Pass Diamond Loupe Implementation
/// @notice Optimized implementation using two-pass approach with pre-counting
/// @dev Algorithm: First pass counts unique facets and their selectors, second pass populates arrays
///      This saves gas by allocating exact array sizes instead of maximum sizes
contract TwoPassDiamondLoupeFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getStorage();
        facet = s.facetAndPosition[_functionSelector].facet;
    }

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        uint256 numSelectors;
        facetSelectors = new bytes4[](selectorCount);
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            if (_facet == facetAddress_) {
                facetSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        assembly ("memory-safe") {
            mstore(facetSelectors, numSelectors)
        }
    }

    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        allFacets = new address[](selectorCount);
        uint256 numFacets;
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            bool continueLoop = false;
            for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                if (facetAddress_ == allFacets[facetIndex]) {
                    continueLoop = true;
                    break;
                }
            }
            if (continueLoop) {
                continueLoop = false;
                continue;
            }
            allFacets[numFacets] = facetAddress_;
            numFacets++;
        }
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    function facets() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;

        // First pass: count unique facets
        uint256 numFacets;
        address[] memory uniqueFacets = new address[](selectorCount);
        uint256[] memory selectorsByFacet = new uint256[](selectorCount);

        // Count unique facets and their selectors
        for (uint256 i; i < selectorCount; i++) {
            address facet = s.facetAndPosition[s.selectors[i]].facet;

            // Look for existing facet
            uint256 facetIndex;
            for (; facetIndex < numFacets; facetIndex++) {
                if (uniqueFacets[facetIndex] == facet) {
                    selectorsByFacet[facetIndex]++;
                    break;
                }
            }

            // If facet not found, add it
            if (facetIndex == numFacets) {
                uniqueFacets[numFacets] = facet;
                selectorsByFacet[numFacets] = 1;
                numFacets++;
            }
        }

        // Allocate return array with exact size
        allFacets = new Facet[](numFacets);

        // Initialize facet arrays with correct sizes
        for (uint256 i; i < numFacets; i++) {
            allFacets[i].facet = uniqueFacets[i];
            allFacets[i].functionSelectors = new bytes4[](selectorsByFacet[i]);
        }

        // Reset selector counts for use as indices
        for (uint256 i; i < numFacets; i++) {
            selectorsByFacet[i] = 0;
        }

        // Second pass: populate selector arrays
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = s.selectors[i];
            address facet = s.facetAndPosition[selector].facet;

            // Find the facet index
            for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                if (allFacets[facetIndex].facet == facet) {
                    allFacets[facetIndex].functionSelectors[selectorsByFacet[facetIndex]++] = selector;
                    break;
                }
            }
        }
    }
}

