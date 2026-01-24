// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * A loupe is a small magnifying glass used to look at diamonds.
 * These functions look at diamonds.
 * These functions are required by ERC-2535 Diamonds, but are not required
 *  for ERC-8109 Diamonds, Simplified.
 * Note that the `facetAddress` function is not in this file. It is in
 * DiamondInspectFacet.sol.
 */
contract DiamondLoupeFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

    /**
     * @notice Data stored for each function selector.
     * @dev Facet address of function selector.
     *      Position of selector in the 'bytes4[] selectors' array.
     */
    struct FacetAndPosition {
        address facet;
        uint32 position;
    }

    /**
     * @custom:storage-location erc8042:erc8109.diamond
     */
    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        /**
         * Array of all function selectors that can be called in the diamond.
         */
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Gets all the function selectors supported by a specific facet.
     * @dev Returns the set of selectors that this diamond currently routes to the
     *      given facet address.
     *
     *      How it works:
     *      1. Iterates through the diamond’s global selector list (s.selectors) — i.e.,
     *         the selectors that have been added to this diamond.
     *      2. For each selector, reads its facet address from diamond storage
     *         (s.facetAndPosition[selector].facet) and compares it to `_facet`.
     *      3. When it matches, writes the selector into a preallocated memory array and
     *         increments a running count.
     *      4. After the scan, updates the logical length of the result array with
     *         assembly to the exact number of matches.
     *
     *      Why this approach:
     *      - Single-pass O(n) scan over all selectors keeps the logic simple and predictable.
     *      - Preallocating to the maximum possible size (total selector count) avoids
     *        repeated reallocations while building the result.
     *      - Trimming the array length at the end yields an exactly sized return value.
     *
     * @param _facet The facet address to filter by.
     * @return facetSelectors The function selectors implemented by `_facet`.
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        uint256 numSelectors;

        facetSelectors = new bytes4[](selectorCount);

        /**
         * Loop through function selectors.
         */
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            if (_facet == s.facetAndPosition[selector].facet) {
                facetSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        /*
         * Set the number of selectors in the array.
         */
        assembly ("memory-safe") {
            mstore(facetSelectors, numSelectors)
        }
    }

    /**
     * @notice Get all the facet addresses used by a diamond.
     * @dev This function returns the unique set of facet addresses that provide functionality
     *      to the diamond.
     *
     *      **How it works:**
     *      1. Uses a memory-based hash map to group facet addresses by the last byte of the address,
     *         reducing linear search costs from O(n²) to approximately O(n) for most cases.
     *      2. Reuses the selectors array memory space to store the unique facet addresses,
     *         avoiding an extra memory allocation for the intermediate array. The selectors
     *         array is overwritten with facet addresses as we iterate.
     *      3. For each selector, looks up its facet address and checks if we've seen this
     *         address before by searching the appropriate hash map bucket.
     *      4. If the facet is new (not found in the bucket), expands the bucket by 4 slots
     *         if it's full or empty, then adds the facet to both the bucket and the return array.
     *      5. If the facet was already seen, skips it to maintain uniqueness.
     *      6. Finally, sets the correct length of the return array to match the number
     *         of unique facets found.
     *
     *      **Why this approach:**
     *      - Hash mapping by last address byte provides O(1) average-case bucket lookup
     *        instead of scanning all previously-found facets linearly for each selector.
     *      - Growing in fixed-size chunks (4 for buckets) keeps reallocations infrequent
     *        and prevents over-allocation, while keeping bucket sizes small for sparse key distributions.
     *      - Reusing the selectors array memory eliminates one memory allocation and reduces
     *        total memory usage, which saves gas.
     *      - This design is optimized for diamonds with many selectors across many facets,
     *        where the original O(n²) nested loop approach becomes prohibitively expensive.
     *      - The 256-bucket hash map trades a small fixed memory cost for dramatic algorithmic
     *        improvement in worst-case scenarios.
     *
     * @return allFacets Array of unique facet addresses used by this diamond.
     */
    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        /*
         * Reuse the selectors array to hold unique facet addresses.
         * As we loop through the selectors, we overwrite earlier slots with facet addresses.
         * The selectors array and the allFacets array point to the same
         * location in memory and use the same memory slots.
         */
        assembly ("memory-safe") {
            allFacets := selectors
        }

        /**
         * Memory-based "hash map" that groups facet addresses by the last byte of their address.
         * Each entry is a dynamically sized array of addresses.
         * Using only the last byte of the address (256 possible values) provides a simple
         * bucketing mechanism to reduce linear search costs across unique facets.
         */
        address[][256] memory map;

        /**
         * The last byte of a facet address, used as an index key into `map`.
         */
        uint256 key;

        /**
         * Reference to the current bucket (a dynamic array of facet addresses) for this key.
         */
        address[] memory bucket;

        /**
         * Counter for the total number of unique facets encountered.
         */
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            /**
             * Extract the last byte of the facet address to use as a bucket key.
             */
            key = uint160(facet) & 0xff;
            /**
             * Retrieve all facet addresses that share the same last address byte.
             */
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                /**
                 * If a facet address is not unique
                 */
                if (bucket[bucketIndex] == facet) {
                    break;
                }
            }
            /**
             * If we didn't find this facet in the bucket (new facet address encountered).
             * Either we looped through all the available slots in the bucket and found no match or
             * the bucket size was 0 because the last address byte hasn't been seen before.
             * Either way we found a new facet address!
             */
            if (bucketIndex == bucket.length) {
                /**
                 * Expand the bucket if it’s full or its length is zero.
                 * We expand the bucket after every 4 entries.
                 * bucketIndex % 4 == 0 check done via & 3 == 0.
                 */
                if (bucketIndex & 3 == 0) {
                    /**
                     * Allocate a new bucket with 4 extra slots and copy the old contents, if any.
                     */
                    address[] memory newBucket = new address[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                /*
                 * Increase the bucket’s logical length by 1.
                 */
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
                /**
                 * Add facet address to the current bucket and to the facet address array.
                 */
                bucket[bucketIndex] = facet;
                allFacets[numFacets] = facet;
                unchecked {
                    numFacets++;
                }
            }
        }
        /*
         * Set the correct length of the allFacets array.
         */
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    /**
     * @notice Struct to hold facet address and its function selectors.
     */
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Gets all facets and their selectors.
     * @dev Returns each unique facet address currently used by the diamond and the
     *      list of function selectors that the diamond maps to that facet.
     *
     *      **How it works:**
     *      1. Uses a memory-based hash map to group facets by the last byte of their address,
     *         reducing linear search costs from O(n²) to approximately O(n) for most cases.
     *      2. Reuses the selectors array memory space to store pointers to Facet structs,
     *         avoiding an extra memory allocation for the intermediate array.
     *      3. For each selector, looks up its facet address and checks if we've seen this
     *         facet before by searching the appropriate hash map bucket.
     *      4. If the facet is new, expands the bucket by 4 slots if it's full or empty,
     *         creates a Facet struct with a 16-slot selector array, and stores a pointer
     *         to it in both the bucket and the facet pointers array.
     *      5. If the facet exists, expands its selector array by 16 slots if full, then
     *         appends the selector to the array.
     *      6. Finally, copies all Facet structs from their pointers into a properly-sized
     *         return array.
     *
     *      **Why this approach:**
     *      - Hash mapping by last address byte provides O(1) average-case bucket lookup
     *        instead of scanning all previously-found facets linearly.
     *      - Growing in fixed-size chunks (4 for buckets, 16 for selector arrays)
     *        keeps reallocations infrequent and prevents over-allocation.
     *      - Reusing the selectors array memory reduces total memory usage and allocation.
     *      - This design is optimized for diamonds with many facets and many selectors,
     *        where the original O(n²) nested loop approach becomes prohibitively expensive.
     *
     * @return facetsAndSelectors Array of Facet structs, each containing a facet address and function selectors.
     */
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorsCount = selectors.length;
        bytes4 selector;

        /**
         * Reuse the selectors memory array to hold pointers to Facet structs in memory.
         * Each pointer is a memory address to a Facet struct in memory.
         * As we loop through the selectors, we overwrite earlier slots with pointers.
         * The selectors array and the facetPointers array point to the same
         * location in memory and use the same memory slots.
         */
        uint256[] memory facetPointers;
        assembly ("memory-safe") {
            facetPointers := selectors
        }

        /**
         * Holds a memory address to a Facet struct.
         */
        uint256 facetPointer;

        /**
         * Facet struct reference used to read/write Facet data at a memory pointer.
         */
        Facet memory facetAndSelectors;

        /**
         * Memory-based "hash map" that groups facet pointers by the last byte of their address.
         * Each entry is a dynamically sized array of uint256 pointers.
         * Using only the last byte of the address (256 possible values) provides a simple
         * bucketing mechanism to reduce linear search costs across unique facets.
         * Each entry in the map is called a "bucket".
         */
        uint256[][256] memory map;

        /**
         * The last byte of a facet address, used as an index key into `map`.
         */
        uint256 key;

        /**
         * Reference to the current bucket (a dynamic array of facet pointers) for this key.
         */
        uint256[] memory bucket;

        /**
         * Counter for the total number of unique facets encountered.
         */
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            /**
             * Extract the last byte of the facet address to use as a bucket key.
             */
            key = uint160(facet) & 0xff;
            /**
             * Retrieve all facet pointers that share the same last address byte.
             */
            bucket = map[key];
            /**
             * Search this bucket for an existing Facet struct matching `facet`.
             */
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                /**
                 * Holds a memory address to a Facet struct
                 */
                facetPointer = bucket[bucketIndex];
                /*
                 * Assign the pointer to the facetAndSelectors variable so we can access the Facet struct.
                 */
                assembly ("memory-safe") {
                    facetAndSelectors := facetPointer
                }
                /**
                 * If this facet was already found before, just append the selector.
                 */
                if (facetAndSelectors.facet == facet) {
                    bytes4[] memory functionSelectors = facetAndSelectors.functionSelectors;
                    uint256 selectorsLength = functionSelectors.length;
                    /**
                     * If the selector array is full (multiple of 16), expand it by 16 slots.
                     * This uses `& 15 == 0` as a cheaper modulus check (selectorsLength % 16 == 0).
                     */
                    if (selectorsLength & 15 == 0) {
                        /**
                         * Allocate a new larger array and copy existing selectors into it.
                         */
                        bytes4[] memory newFunctionSelectors = new bytes4[](selectorsLength + 16);
                        for (uint256 k; k < selectorsLength; k++) {
                            newFunctionSelectors[k] = functionSelectors[k];
                        }
                        functionSelectors = newFunctionSelectors;
                        facetAndSelectors.functionSelectors = functionSelectors;
                    }
                    /*
                     * Increment the logical selector array length.
                     */
                    assembly ("memory-safe") {
                        mstore(functionSelectors, add(selectorsLength, 1))
                    }
                    /**
                     * Store the new selector.
                     */
                    functionSelectors[selectorsLength] = selector;
                    break;
                }
            }

            /**
             * If we didn't find this facet in the bucket (new facet address encountered).
             * Either we looped through all the available slots in the bucket and found no match or
             * the bucket size was 0 because the last address byte hasn't been seen before.
             * Either way we found a new facet address!
             */
            if (bucket.length == bucketIndex) {
                /**
                 * Expand the bucket if it’s full or its length is zero.
                 * We expand the bucket after every 4 entries.
                 * bucketIndex % 4 == 0 check done via & 3 == 0.
                 */
                if (bucketIndex & 3 == 0) {
                    /**
                     * Allocate a new bucket with 4 extra slots and copy the old contents, if any.
                     */
                    uint256[] memory newBucket = new uint256[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                /*
                 * Increase the bucket’s logical length by 1.
                 */
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
                /*
                 * Make selector slots
                 */
                bytes4[] memory functionSelectors = new bytes4[](16);
                /*
                 * Set the its logical length to 1
                 */
                assembly ("memory-safe") {
                    mstore(functionSelectors, 1)
                }
                /**
                 * Add the selector
                 */
                functionSelectors[0] = selector;
                /**
                 * Create a new Facet struct for this facet address.
                 */
                facetAndSelectors = Facet({facet: facet, functionSelectors: functionSelectors});
                /*
                 * Store a pointer to the new struct.
                 */
                assembly ("memory-safe") {
                    facetPointer := facetAndSelectors
                }
                /**
                 * Add pointer to the current bucket and to the facet pointer array.
                 */
                bucket[bucketIndex] = facetPointer;
                facetPointers[numFacets] = facetPointer;
                unchecked {
                    numFacets++;
                }
            }
        }

        /**
         * Allocate the final return array with the exact number of unique facets found.
         */
        facetsAndSelectors = new Facet[](numFacets);

        /**
         * Copy each Facet struct into the return array.
         */
        for (uint256 i; i < numFacets; i++) {
            facetPointer = facetPointers[i];
            assembly ("memory-safe") {
                facetAndSelectors := facetPointer
            }
            facetsAndSelectors[i] = facetAndSelectors;
        }
    }
}
