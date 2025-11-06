// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

// The functions in DiamondLoupeFacet MUST be added to a diamond.
// The EIP-2535 Diamond standard requires these functions.
contract DiamondLoupeFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    /// @notice Data stored for each function selector
    /// @dev Facet address of function selector
    ///      Position of selector in the 'bytes4[] selectors' array
    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    /// @custom:storage-location erc8042:compose.diamond
    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        // Array of all function selectors that can be called in the diamond
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Struct to hold facet address and its function selectors
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
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

        // // Reset selector counts for use as indices
        // for (uint256 i; i < numFacets; i++) {
        //     selectorsByFacet[i] = 0;
        // }

        // Second pass: populate selector arrays
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = s.selectors[i];
            address facet = s.facetAndPosition[selector].facet;

            // Find the facet index
            for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                if (allFacets[facetIndex].facet == facet) {
                    allFacets[facetIndex].functionSelectors[--selectorsByFacet[facetIndex]] = selector;
                    break;
                }
            }
        }
    }

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetSelectors The function selectors associated with a facet address.
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorCount = selectors.length;
        uint256 numSelectors;
        facetSelectors = new bytes4[](0);
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            if (_facet == facetAddress_) {
                numSelectors++;
                assembly ("memory-safe") {
                    // Store selector in the next position in the facetSelectors array
                    mstore(add(facetSelectors, mul(numSelectors, 0x20)), selector)
                }
            }
        }
        assembly ("memory-safe") {
            // Set the total number of selectors in the array
            mstore(facetSelectors, numSelectors)
            // Properly allocate memory by setting memory pointer after facetSelectors array
            mstore(0x40, add(0x20, add(facetSelectors, mul(numSelectors, 0x20))))
        }
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return allFacets The facet addresses.
    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        // create an array set to the maximum size possible
        allFacets = new address[](selectorCount);
        uint256 numFacets;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            bool continueLoop = false;
            // see if we have collected the address already and break out of loop if we have
            for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
                if (facetAddress_ == allFacets[facetIndex]) {
                    continueLoop = true;
                    break;
                }
            }
            // continue loop if we already have the address
            if (continueLoop) {
                continueLoop = false;
                continue;
            }
            // include address
            allFacets[numFacets] = facetAddress_;
            numFacets++;
        }
        // Set the number of facet addresses in the array
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    /// @notice Gets the facet address that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facet The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getStorage();
        facet = s.facetAndPosition[_functionSelector].facet;
    }
}
