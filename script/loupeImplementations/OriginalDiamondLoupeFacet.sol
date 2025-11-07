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
        allFacets = new Facet[](selectorCount);
        uint16[] memory numFacetSelectors = new uint16[](selectorCount);
        uint256 numFacets;
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            bool continueLoop = false;
            for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                if (allFacets[facetIndex].facet == facetAddress_) {
                    allFacets[facetIndex].functionSelectors[numFacetSelectors[facetIndex]] = selector;
                    numFacetSelectors[facetIndex]++;
                    continueLoop = true;
                    break;
                }
            }
            if (continueLoop) {
                continueLoop = false;
                continue;
            }
            allFacets[numFacets].facet = facetAddress_;
            allFacets[numFacets].functionSelectors = new bytes4[](selectorCount);
            allFacets[numFacets].functionSelectors[0] = selector;
            numFacetSelectors[numFacets] = 1;
            numFacets++;
        }
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
            uint256 numSelectors = numFacetSelectors[facetIndex];
            bytes4[] memory selectors = allFacets[facetIndex].functionSelectors;
            assembly ("memory-safe") {
                mstore(selectors, numSelectors)
            }
        }
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }
}
