// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title Collision Map Diamond Loupe Implementation
/// @notice Optimized implementation using collision map for O(1) facet uniqueness checks
/// @dev Algorithm: Uses a 256-bit collision map based on the last byte of facet addresses
///      to quickly check if a facet might already exist. Falls back to linear search only
///      on hash collisions. This saves gas by avoiding unnecessary linear searches for
///      most facet addresses.
contract CollisionMapDiamondLoupeFacet {
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

        // Collision map: 256-bit bitmap where each bit represents a possible last byte value
        // This allows O(1) check for potential duplicates before falling back to linear search
        uint256 collisionMap;

        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;

            // Extract last byte of address for collision map lookup
            uint256 lastByte = uint256(uint160(facetAddress_)) & 0xff;
            uint256 bitMask = 1 << lastByte;

            bool found = false;

            // O(1) check: if bit is set, facet with this last byte might exist
            if ((collisionMap & bitMask) != 0) {
                // Fallback to linear search only on potential collision
                for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                    if (allFacets[facetIndex] == facetAddress_) {
                        found = true;
                        break;
                    }
                }
            }

            // If not found, add to array and update collision map
            if (!found) {
                allFacets[numFacets] = facetAddress_;
                collisionMap |= bitMask;
                unchecked {
                    numFacets++;
                }
            }
        }

        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    function facets() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;

        // First pass: count unique facets using collision map
        uint256 numFacets;
        address[] memory uniqueFacets = new address[](selectorCount);
        uint256[] memory selectorsByFacet = new uint256[](selectorCount);
        uint256 collisionMap;

        for (uint256 i; i < selectorCount; i++) {
            address facet = s.facetAndPosition[s.selectors[i]].facet;

            uint256 lastByte = uint256(uint160(facet)) & 0xff;
            uint256 bitMask = 1 << lastByte;

            uint256 facetIndex = type(uint256).max;

            // O(1) check with collision map
            if ((collisionMap & bitMask) != 0) {
                // Linear search only on potential collision
                for (uint256 j; j < numFacets; j++) {
                    if (uniqueFacets[j] == facet) {
                        facetIndex = j;
                        selectorsByFacet[j]++;
                        break;
                    }
                }
            }

            // If facet not found, add it
            if (facetIndex == type(uint256).max) {
                uniqueFacets[numFacets] = facet;
                selectorsByFacet[numFacets] = 1;
                collisionMap |= bitMask;
                unchecked {
                    numFacets++;
                }
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
