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

    /// @notice Gets the facet address that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facet The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getStorage();
        facet = s.facetAndPosition[_functionSelector].facet;
    }

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetSelectors The function selectors associated with a facet address.
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorCount = selectors.length;
        uint256 numSelectors;
        facetSelectors = new bytes4[](selectorCount);
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address selectorFacet = s.facetAndPosition[selector].facet;
            if (_facet == selectorFacet) {
                facetSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        // Set the number of selectors in the array
        assembly ("memory-safe") {
            mstore(facetSelectors, numSelectors)
        }
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return allFacets The facet addresses.
    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        // Allocate the largest possible number of facet addresses
        allFacets = new address[](selectorsCount);

        // Memory-based "hash map" that groups facet addresses by the last byte of their address.
        // Each entry is a dynamically sized array of addresses
        // Using only the last byte of the address (256 possible values) provides a simple
        // bucketing mechanism to reduce linear search costs across unique facets.
        address[][256] memory map;

        // The last byte of a facet address, used as an index key into `map`.
        uint256 key;

        // Reference to the current bucket (a dynamic array of facet addresses) for this key.
        address[] memory bucket;

        // Counter for the total number of unique facets encountered.
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Extract the last byte of the facet address to use as a bucket key.
            key = uint160(facet) & 0xff;
            // Retrieve all facet addresses that share the same last address byte.
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                // If a facet address is not unique
                if (bucket[bucketIndex] == facet) {
                    break;
                }
            }
            // If we didn't find this facet in the bucket (new facet address encountered).
            // Either we looped through all the available slots in the bucket and found no match or
            // the bucket size was 0 because the last address byte hasn't been seen before.
            // Either way we found a new facet address!
            if (bucketIndex == bucket.length) {
                // Expand the bucket if it’s full or its length is zero.
                // We expand the bucket after every 4 entries.
                // bucketIndex % 4 == 0 check done via & 3 == 0.
                if (bucketIndex & 3 == 0) {
                    // Allocate a new bucket with 4 extra slots and copy the old contents, if any.
                    address[] memory newBucket = new address[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                // Increase the bucket’s logical length by 1.
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
                // Add facet address to the current bucket and to the facet address array.
                bucket[bucketIndex] = facet;
                allFacets[numFacets] = facet;
                unchecked {
                    numFacets++;
                }
            }
        }
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    /// @notice Struct to hold facet address and its function selectors
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facets and their selectors.
    /// @return facetsAndSelectors Facet
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorsCount = selectors.length;
        bytes4 selector;

        // Allocates enough space for pointers to Facet structs in memory.
        // Each used space will hold an address to a Facet struct in memory.
        uint256[] memory facetPointers = new uint256[](selectorsCount);

        // Holds a memory address to a Facet struct.
        uint256 facetPointer;

        // Facet struct reference used to read/write Facet data at a memory pointer.
        Facet memory facetAndSelectors;

        // Memory-based "hash map" that groups facet pointers by the last byte of their address.
        // Each entry is a dynamically sized array of uint256 pointers.
        // Using only the last byte of the address (256 possible values) provides a simple
        // bucketing mechanism to reduce linear search costs across unique facets.
        uint256[][256] memory map;

        // The last byte of a facet address, used as an index key into `map`.
        uint256 key;

        // Reference to the current bucket (a dynamic array of facet pointers) for this key.
        uint256[] memory bucket;

        // Counter for the total number of unique facets encountered.
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Extract the last byte of the facet address to use as a bucket key.
            key = uint160(facet) & 0xff;
            // Retrieve all facet pointers that share the same last address byte.
            bucket = map[key];
            // Search this bucket for an existing Facet struct matching `facet`.
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                // Holds a memory address to a Facet struct
                facetPointer = bucket[bucketIndex];
                // Assign the pointer to the facetAndSelectors variable so we can access the Facet struct
                assembly ("memory-safe") {
                    facetAndSelectors := facetPointer
                }
                // If this facet was already found before, just append the selector.
                if (facetAndSelectors.facet == facet) {
                    bytes4[] memory functionSelectors = facetAndSelectors.functionSelectors;
                    uint256 selectorsLength = functionSelectors.length;
                    // If the selector array is full (multiple of 16), expand it by 16 slots.
                    // This uses `& 15 == 0` as a cheaper modulus check (selectorsLength % 16 == 0).
                    if (selectorsLength & 15 == 0) {
                        // Allocate a new larger array and copy existing selectors into it.
                        bytes4[] memory newFunctionSelectors = new bytes4[](selectorsLength + 16);
                        for (uint256 k; k < selectorsLength; k++) {
                            newFunctionSelectors[k] = functionSelectors[k];
                        }                        
                        functionSelectors = newFunctionSelectors;
                        facetAndSelectors.functionSelectors = functionSelectors;
                    }
                    // Increment the logical selector array length.                    
                    assembly ("memory-safe") {
                        mstore(functionSelectors, add(selectorsLength, 1))
                    }
                    // Store the new selector.
                    functionSelectors[selectorsLength] = selector;
                    break;
                }
            }

            // If we didn't find this facet in the bucket (new facet address encountered).
            // Either we looped through all the available slots in the bucket and found no match or
            // the bucket size was 0 because the last address byte hasn't been seen before.
            // Either way we found a new facet address!
            if (bucket.length == bucketIndex) {
                // Expand the bucket if it’s full or its length is zero.
                // We expand the bucket after every 4 entries.
                // bucketIndex % 4 == 0 check done via & 3 == 0.
                if (bucketIndex & 3 == 0) {
                    // Allocate a new bucket with 4 extra slots and copy the old contents, if any.
                    uint256[] memory newBucket = new uint256[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                // Increase the bucket’s logical length by 1.
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
                // Make selector slots
                bytes4[] memory functionSelectors = new bytes4[](16);
                // Set the its logical length to 1
                assembly ("memory-safe") {
                    mstore(functionSelectors, 1)
                }
                // Add the selector
                functionSelectors[0] = selector;
                // Create a new Facet struct for this facet address.
                facetAndSelectors = Facet({facet: facet, functionSelectors: functionSelectors});
                // Store a pointer to the new struct.
                assembly ("memory-safe") {
                    facetPointer := facetAndSelectors
                }
                // Add pointer to the current bucket and to the facet pointer array.
                bucket[bucketIndex] = facetPointer;
                facetPointers[numFacets] = facetPointer;
                unchecked {
                    numFacets++;
                }
            }
        }

        // Allocate the final return array with the exact number of unique facets found.
        facetsAndSelectors = new Facet[](numFacets);

        // Copy each Facet struct into the return array.
        for (uint256 i; i < numFacets; i++) {
            facetPointer = facetPointers[i];
            assembly ("memory-safe") {
                facetAndSelectors := facetPointer
            }
            facetsAndSelectors[i].facet = facetAndSelectors.facet;
            facetsAndSelectors[i].functionSelectors = facetAndSelectors.functionSelectors;
        }
    }
}
