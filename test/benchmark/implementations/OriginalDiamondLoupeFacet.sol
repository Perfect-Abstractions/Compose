// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title Original DiamondLoupeFacet Implementation
/// @notice This is the original, unoptimized implementation for gas benchmarking comparison
/// @dev This implementation uses simple linear search without bucketing optimization
contract OriginalDiamondLoupeFacet {
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
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            if (_facet == s.facetAndPosition[s.selectors[selectorIndex]].facet) {
                numSelectors++;
            }
        }
        facetSelectors = new bytes4[](numSelectors);
        uint256 selectorSlot;
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            if (_facet == s.facetAndPosition[selector].facet) {
                facetSelectors[selectorSlot] = selector;
                selectorSlot++;
            }
        }
    }

    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        address[] memory facetsBuffer = new address[](selectorCount);
        uint256 numFacets;
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            address facetAddress_ = s.facetAndPosition[s.selectors[selectorIndex]].facet;
            bool exists;
            for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                if (facetAddress_ == facetsBuffer[facetIndex]) {
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                facetsBuffer[numFacets] = facetAddress_;
                numFacets++;
            }
        }
        allFacets = new address[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            allFacets[i] = facetsBuffer[i];
        }
    }

    function facets() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        address[] memory facetsBuffer = new address[](selectorCount);
        uint16[] memory selectorCounts = new uint16[](selectorCount);
        uint256 numFacets;

        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            uint256 facetIndex;
            for (; facetIndex < numFacets; facetIndex++) {
                if (facetsBuffer[facetIndex] == facetAddress_) {
                    selectorCounts[facetIndex]++;
                    break;
                }
            }
            if (facetIndex == numFacets) {
                facetsBuffer[numFacets] = facetAddress_;
                selectorCounts[numFacets] = 1;
                numFacets++;
            }
        }

        allFacets = new Facet[](numFacets);
        bytes4[][] memory selectorsPerFacet = new bytes4[][](numFacets);
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
            uint16 numSelectors = selectorCounts[facetIndex];
            selectorsPerFacet[facetIndex] = new bytes4[](numSelectors);
            allFacets[facetIndex].facet = facetsBuffer[facetIndex];
            allFacets[facetIndex].functionSelectors = selectorsPerFacet[facetIndex];
        }

        uint16[] memory writePositions = new uint16[](numFacets);
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            uint256 facetIndex;
            for (; facetIndex < numFacets; facetIndex++) {
                if (allFacets[facetIndex].facet == facetAddress_) {
                    selectorsPerFacet[facetIndex][writePositions[facetIndex]] = selector;
                    writePositions[facetIndex]++;
                    break;
                }
            }
        }
    }
}

