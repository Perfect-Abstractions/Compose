// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {console} from "forge-std/console.sol";

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

    // Temporary struct to hold facet info

    function facets25() external view returns (Facet[] memory allFacets) {
        uint256 numFacets;

        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        uint256[] memory selectorsFacetID = new uint256[](selectorCount);
        uint256[] memory uniqueFacets = new uint256[](1); // [(160)address |(96) corresponding selectors count]
        uint256 facetIndex;

        for (uint256 i; i < selectorCount; i++) {
            address facet = s.facetAndPosition[s.selectors[i]].facet;
            // Look for existing facet
            for (facetIndex = 0; facetIndex < numFacets; facetIndex++) {
                if (uniqueFacets[facetIndex] >> 96 == uint160(facet)) {
                    uniqueFacets[facetIndex]++;
                    break;
                }
            }
            // If facet not found, add it
            if (facetIndex == numFacets) {
                numFacets++;
                assembly ("memory-safe") {
                    mstore(uniqueFacets, numFacets)
                }
                uniqueFacets[facetIndex] = (uint256(uint160(facet)) << 96) + 1;
            }
            selectorsFacetID[i] = facetIndex;
        }
        assembly {
            mstore(0x40, add(add(uniqueFacets, 0x20), mul(mload(uniqueFacets), 0x20)))
        }

        allFacets = new Facet[](numFacets);

        for (uint256 i; i < numFacets; i++) {
            allFacets[i].functionSelectors = new bytes4[](uint256(uniqueFacets[i]) & 0xffffffffffffffffffffffff);
            allFacets[i].facet = address(uint160(uniqueFacets[i] >> 96));
        }

        uint256[] memory selectorsIdx = new uint256[](numFacets);
        for (uint256 i; i < selectorCount; i++) {
            allFacets[selectorsFacetID[i]].functionSelectors[selectorsIdx[selectorsFacetID[i]]++] = s.selectors[i];
        }
    }

    struct FacetInfo {
        address facet;
        bytes4[] selectors;
        uint256 count;
    }

    function facets16() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorsCount = selectors.length;

        // We will fill in the actual Facet structs as we go.
        facetsAndSelectors = new Facet[]((selectorsCount + 2) / 3);

        // Memory-based mapping from the last byte of a facet address to
        // a dynamic array of pointers to Facet structs
        // This is a static array of dynamic uint256 arrays
        uint256[][256] memory map;

        // Number of unique facet addresses
        uint256 numFacets;

        for (uint256 i = 0; i < selectorsCount; i++) {
            bytes4 selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Get the last byte of an address
            uint256 key = uint160(facet) & 0xff;
            // Get an array of indexes to Facet structs in facetsAndSelectors
            // facet last byte
            uint256[] memory bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                uint256 facetIndex = bucket[bucketIndex];
                Facet memory facetAndSelectors = facetsAndSelectors[facetIndex];
                // If we have found this facet before, then we add the selector
                if (facetAndSelectors.facet == facet) {
                    uint256 selectorsLength = facetAndSelectors.functionSelectors.length;
                    bytes4[] memory functionSelectors;
                    // If there are no more empty facetAndSelector.selectors slots then we make more.
                    if (selectorsLength & 15 == 0) {
                        // expand array
                        functionSelectors = new bytes4[](selectorsLength + 16);
                        for (uint256 k; k < selectorsLength; k++) {
                            functionSelectors[k] = facetAndSelectors.functionSelectors[k];
                        }
                        assembly ("memory-safe") {
                            mstore(functionSelectors, selectorsLength)
                        }
                        facetAndSelectors.functionSelectors = functionSelectors;
                    }
                    // Increment the length of the facetAndSelectors.functionSelectors array
                    functionSelectors = facetAndSelectors.functionSelectors;
                    assembly ("memory-safe") {
                        mstore(functionSelectors, add(mload(functionSelectors), 1))
                    }
                    // add selector
                    functionSelectors[selectorsLength] = selector;
                    break;
                }
            }

            // Looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if (bucket.length == bucketIndex) {
                // Make more bucket slots
                uint256[] memory newBucket = new uint256[](bucketIndex + 1);
                for (uint256 k; k < bucketIndex; k++) {
                    newBucket[k] = bucket[k];
                }
                bucket = newBucket;
                bucket[bucketIndex] = numFacets;
                map[key] = bucket;
                // Allocate 16 selector slots
                bytes4[] memory functionSelectors = new bytes4[](16);
                // Set the length of the array to 1
                assembly ("memory-safe") {
                    mstore(functionSelectors, 1)
                }
                functionSelectors[0] = selector;
                if (numFacets == facetsAndSelectors.length) {
                    Facet[] memory newFacetsAndSelectors = new Facet[](numFacets + (selectorsCount + 2) / 3);
                    for (uint256 j; j < numFacets; j++) {
                        newFacetsAndSelectors[j] = facetsAndSelectors[j];
                    }
                    facetsAndSelectors = newFacetsAndSelectors;
                }
                facetsAndSelectors[numFacets] = Facet({facet: facet, functionSelectors: functionSelectors});
                unchecked {
                    numFacets++;
                }
            }
        }
        // Set the correct number of facets
        assembly ("memory-safe") {
            mstore(facetsAndSelectors, numFacets)
        }
    }

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    function facets15() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        // This is an array of pointers to Face structs which don't exist yet.
        // We will fill in the actual Facet structs as we go.
        facetsAndSelectors = new Facet[](selectorsCount);
        // Holds a memory address to a Facet struct
        uint256 facetIndex;
        // We assign a pointer to this variable to read a Facet struct

        // Memory-based mapping from the last byte of a facet address to
        // a dynamic array of pointers to Facet structs
        // This is a static array of dynamic uint256 arrays
        uint256[][256] memory map;
        // The last byte of a facet address
        uint256 key;
        // An array of pointers to Facet structs
        // Each bucket is an array of pointers to Facet structs that have
        // the same facet address last byte
        uint256[] memory bucket;

        address facet;

        bytes4[] memory functionSelectors;

        // count unique facets
        uint256 numFacets;
        for (uint256 i = 0; i < selectorsCount; i++) {
            selector = selectors[i];
            facet = s.facetAndPosition[selector].facet;
            // Get the last byte of an address
            key = uint160(facet) & 0xff;
            // Get an array of pointers to Facet structs that have the same
            // facet last byte
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                facetIndex = bucket[bucketIndex];
                Facet memory facetAndSelectors = facetsAndSelectors[facetIndex];
                // If we have found this facet before, then we add the selector
                if (facetAndSelectors.facet == facet) {
                    uint256 selectorsLength = facetAndSelectors.functionSelectors.length;
                    // If there are no more empty facetAndSelector.selectors slots then we make more.
                    if (selectorsLength & 15 == 0) {
                        // expand array
                        bytes4[] memory selectorStorage = new bytes4[](selectorsLength + 16);
                        for (uint256 k; k < selectorsLength; k++) {
                            selectorStorage[k] = facetAndSelectors.functionSelectors[k];
                        }
                        assembly ("memory-safe") {
                            mstore(selectorStorage, selectorsLength)
                        }
                        facetAndSelectors.functionSelectors = selectorStorage;
                    }
                    // Increment the length of the facetAndSelectors.functionSelectors array
                    functionSelectors = facetAndSelectors.functionSelectors;
                    assembly ("memory-safe") {
                        mstore(functionSelectors, add(mload(functionSelectors), 1))
                    }
                    // add selector
                    functionSelectors[selectorsLength] = selector;
                    break;
                }
            }

            // Looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if (bucket.length == bucketIndex) {
                // Make bucket slots
                uint256[] memory newBucket = new uint256[](bucketIndex + 1);
                for (uint256 k; k < bucketIndex; k++) {
                    newBucket[k] = bucket[k];
                }
                bucket = newBucket;
                map[key] = bucket;
                // Allocate 16 selector slots
                functionSelectors = new bytes4[](16);
                // Set the length of the array to 1
                assembly ("memory-safe") {
                    mstore(functionSelectors, 1)
                }
                functionSelectors[0] = selector;
                bucket[bucketIndex] = numFacets;
                facetsAndSelectors[numFacets] = Facet({facet: facet, functionSelectors: functionSelectors});
                unchecked {
                    numFacets++;
                }
            }
        }
        // Set the correct number of facets
        assembly ("memory-safe") {
            mstore(facetsAndSelectors, numFacets)
        }
    }

    function facets142() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorsCount = selectors.length;
        bytes4 selector;

        // Reuse the selectors array to hold pointers to Facet structs in memory.
        // As we loop through the selectors, we overwrite slots with pointers.
        // The selectors array and the facetPointers array point to the same
        // location in memory and use the same memory slots.
        uint256[] memory facetPointers;
        assembly ("memory-safe") {
            facetPointers := selectors
        }
        // uint256[] memory facetPointers = new uint256[](selectorsCount);

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

    function facets141() external view returns (Facet[] memory facetsAndSelectors) {
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

    function facets14() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        // This is an array of pointers to Face structs which don't exist yet.
        // We will fill in the actual Facet structs as we go.
        uint256[] memory facetPointers = new uint256[](selectorsCount);
        // Holds a memory address to a Facet struct
        uint256 pointer;
        // We assign a pointer to this variable to read a Facet struct
        Facet memory facetAndSelectors;

        // Memory-based mapping from the last byte of a facet address to
        // a dynamic array of pointers to Facet structs
        // This is a static array of dynamic uint256 arrays
        uint256[][256] memory map;
        // The last byte of a facet address
        uint256 key;
        // An array of pointers to Facet structs
        // Each bucket is an array of pointers to Facet structs that have
        // the same facet address last byte
        uint256[] memory bucket;

        // count unique facets
        uint256 numFacets;
        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Get the last byte of an address
            key = uint160(facet) & 0xff;
            // Get an array of pointers to Facet structs that have the same
            // facet last byte
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                pointer = bucket[bucketIndex];
                // If pointer == 0 then there is an empty slot in the bucket
                // that we will fill with a new pointer to a new Facet struct
                if (pointer == 0) {
                    // Allocate 16 slots for function selectors
                    bytes4[] memory functionSelectors = new bytes4[](16);
                    // Set the length of the array to 1
                    assembly {
                        mstore(functionSelectors, 1)
                    }
                    functionSelectors[0] = selector;
                    facetAndSelectors = Facet({facet: facet, functionSelectors: functionSelectors});
                    assembly ("memory-safe") {
                        pointer := facetAndSelectors
                    }
                    bucket[bucketIndex] = pointer;
                    facetPointers[numFacets] = pointer;
                    unchecked {
                        numFacets++;
                    }
                    break;
                }
                // Assign the pointer to the facetAndSelectors variable so we can access the Facet struct
                assembly ("memory-safe") {
                    facetAndSelectors := pointer
                }
                // If we have found this facet before, then we add the selector
                if (facetAndSelectors.facet == facet) {
                    uint256 selectorsLength = facetAndSelectors.functionSelectors.length;
                    // If there are no more empty facetAndSelector.selectors slots then we make more.

                    if (selectorsLength & 15 == 0) {
                        // expand array
                        bytes4[] memory selectorStorage = new bytes4[](selectorsLength + 16);
                        for (uint256 k; k < selectorsLength; k++) {
                            selectorStorage[k] = facetAndSelectors.functionSelectors[k];
                        }
                        assembly ("memory-safe") {
                            mstore(selectorStorage, selectorsLength)
                        }
                        facetAndSelectors.functionSelectors = selectorStorage;
                    }
                    // Increment the length of the facetAndSelectors.functionSelectors array
                    bytes4[] memory functionSelectors = facetAndSelectors.functionSelectors;
                    assembly ("memory-safe") {
                        mstore(functionSelectors, add(mload(functionSelectors), 1))
                    }
                    functionSelectors[selectorsLength] = selector;
                    break;
                }
            }

            // Either we have looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if (bucket.length == bucketIndex) {
                // Make bucket slots
                uint256[] memory newPointers = new uint256[](bucketIndex + 3);
                for (uint256 k; k < bucketIndex; k++) {
                    newPointers[k] = bucket[k];
                }
                bucket = newPointers;
                map[key] = bucket;
                // Make selector slots
                bytes4[] memory functionSelectors = new bytes4[](16);
                assembly ("memory-safe") {
                    mstore(functionSelectors, 1)
                }
                functionSelectors[0] = selector;
                facetAndSelectors = Facet({facet: facet, functionSelectors: functionSelectors});
                assembly ("memory-safe") {
                    pointer := facetAndSelectors
                }
                bucket[bucketIndex] = pointer;
                facetPointers[numFacets] = pointer;
                unchecked {
                    numFacets++;
                }
            }
        }

        // Allocate return array with exact size
        facetsAndSelectors = new Facet[](numFacets);

        // Fill up facetsAndSelectors
        for (uint256 i; i < numFacets; i++) {
            pointer = facetPointers[i];
            assembly ("memory-safe") {
                facetAndSelectors := pointer
            }
            facetsAndSelectors[i].facet = facetAndSelectors.facet;
            facetsAndSelectors[i].functionSelectors = facetAndSelectors.functionSelectors;
        }
    }

    function facets13() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        // This is an array of pointers to FacetInfo structs which don't exist yet.
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](selectorsCount);
        // Holds a memory address to a FacetInfo struct
        uint256 pointer;
        FacetInfo memory facetInfo;

        // Memory-based mapping from the last byte of a facet address to
        // a dynamic array of pointers to FacetInfo structs
        uint256[][256] memory map;
        // The last byte of a facet address
        uint256 key;
        // An array of pointers to FacetInfo structs
        uint256[] memory bucket;

        // count unique facets
        uint256 numFacets;
        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Get the last byte of an address
            key = uint160(facet) & 0xff;
            // Get an array of pointers to FacetInfo structs that have the same
            // facet last byte
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                pointer = bucket[bucketIndex];
                // If pointer == 0 then there is an empty slot in the bucket
                // that we will fill with a new pointer to a new FacetInfo struct
                if (pointer == 0) {
                    bytes4[] memory selectorStorage = new bytes4[](20);
                    selectorStorage[0] = selector;
                    facetInfo = FacetInfo({facet: facet, selectors: selectorStorage, count: 1});
                    assembly ("memory-safe") {
                        pointer := facetInfo
                    }
                    bucket[bucketIndex] = pointer;
                    facetInfoPointers[numFacets] = pointer;
                    unchecked {
                        numFacets++;
                    }
                    break;
                }
                // Assign the pointer to a variable so we can access the facetInfo struct
                assembly ("memory-safe") {
                    facetInfo := pointer
                }
                // If we have found this facet before, then we add the selector
                if (facetInfo.facet == facet) {
                    // If there are no more empty facetInfo.selectors slots then we make more
                    if (facetInfo.count == facetInfo.selectors.length) {
                        // expand array
                        bytes4[] memory selectorStorage = new bytes4[](facetInfo.count + 20);
                        for (uint256 k; k < facetInfo.count; k++) {
                            selectorStorage[k] = facetInfo.selectors[k];
                        }
                        facetInfo.selectors = selectorStorage;
                    }
                    facetInfo.selectors[facetInfo.count] = selector;
                    unchecked {
                        facetInfo.count++;
                    }
                    break;
                }
            }

            // Either we have looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if (bucket.length == bucketIndex) {
                // Make more bucket slots
                uint256[] memory newPointers = new uint256[](bucketIndex + 3);
                for (uint256 k; k < bucketIndex; k++) {
                    newPointers[k] = bucket[k];
                }
                bucket = newPointers;
                map[key] = bucket;
                // Make selector slots
                bytes4[] memory selectorStorage = new bytes4[](20);
                selectorStorage[0] = selector;
                facetInfo = FacetInfo({facet: facet, selectors: selectorStorage, count: 1});
                assembly ("memory-safe") {
                    pointer := facetInfo
                }
                bucket[bucketIndex] = pointer;
                facetInfoPointers[numFacets] = pointer;
                unchecked {
                    numFacets++;
                }
            }
        }

        // Allocate return array with exact size
        facetsAndSelectors = new Facet[](numFacets);

        // Fill up facetsAndSelectors
        for (uint256 i; i < numFacets; i++) {
            pointer = facetInfoPointers[i];
            assembly ("memory-safe") {
                facetInfo := pointer
            }
            facetsAndSelectors[i].facet = facetInfo.facet;
            bytes4[] memory facetSelectors = facetInfo.selectors;
            uint256 facetSelectorCount = facetInfo.count;
            assembly {
                mstore(facetSelectors, facetSelectorCount)
            }
            facetsAndSelectors[i].functionSelectors = facetSelectors;
        }
    }

    /// @notice Gets all facets and their selectors.
    /// @return allFacets Facet
    function facetsOld() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorCount = selectors.length;
        // create an array set to the maximum size possible
        allFacets = new Facet[](selectorCount);
        // create an array for counting the number of selectors for each facet
        uint256[] memory numFacetSelectors = new uint256[](selectorCount);
        // total number of facets
        uint256 numFacets;
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            // find the functionSelectors array for selector and add selector to it
            uint256 facetIndex = 0;
            for (; facetIndex < numFacets; facetIndex++) {
                if (allFacets[facetIndex].facet == facetAddress_) {
                    allFacets[facetIndex].functionSelectors[numFacetSelectors[facetIndex]] = selector;
                    numFacetSelectors[facetIndex]++;
                    break;
                }
            }

            if (facetIndex == numFacets) {
                // create a new functionSelectors array for selector
                allFacets[numFacets].facet = facetAddress_;
                allFacets[numFacets].functionSelectors = new bytes4[](selectorCount);
                allFacets[numFacets].functionSelectors[0] = selector;
                numFacetSelectors[numFacets] = 1;
                numFacets++;
            }
        }
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
            uint256 numSelectors = numFacetSelectors[facetIndex];
            selectors = allFacets[facetIndex].functionSelectors;
            // setting the number of selectors
            assembly ("memory-safe") {
                mstore(selectors, numSelectors)
            }
        }

        // setting the number of facets
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    // /// @notice Gets all the function selectors supported by a specific facet.
    // /// @param _facet The facet address.
    // /// @return facetSelectors The function selectors associated with a facet address.
    // function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
    //     DiamondStorage storage s = getStorage();
    //     bytes4[] memory selectors = s.selectors;
    //     uint256 selectorCount = selectors.length;
    //     uint256 numSelectors;
    //     facetSelectors = new bytes4[](selectorCount);
    //     // loop through function selectors
    //     for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
    //         bytes4 selector = s.selectors[selectorIndex];
    //         address selectorFacet = s.facetAndPosition[selector].facet;
    //         if (_facet == selectorFacet) {
    //             facetSelectors[numSelectors] = selector;
    //             numSelectors++;
    //         }
    //     }
    //     // Set the number of selectors in the array
    //     assembly ("memory-safe") {
    //         mstore(facetSelectors, numSelectors)
    //     }
    // }

    //     function facetAddresses3() external view returns (address[] memory allFacets) {
    //     assembly {
    //         // --- 0. Setup and Storage Pointers ---

    //         // Custom base storage position: keccak256("compose.diamond")
    //         let COMPOSE_DIAMOND_SLOT := 0x9dea51a0972159e0838d8a036f01982ec1d78b3b2a8e1570e8f17e011984b3ce

    //         // Diamond Storage Layout:
    //         let FACET_MAP_SLOT := COMPOSE_DIAMOND_SLOT          // facetAndPosition mapping slot

    //         // keccak256(COMPOSE_DIAMOND_SLOT + 1)
    //         let SELECTORS_BASE := 0x72c389824b9f57a6b0843a72db8f29826b9ecb297b4acd2b1188a7db453a6934

    //         // Memory start for the return array
    //         let FACETS_ARRAY_PTR := 0x80

    //         // Start of array elements (FACETS_ARRAY_PTR + 32)
    //         let FACETS_ELEMENTS_PTR := 0xa0

    //         let selectorCount := sload(add(COMPOSE_DIAMOND_SLOT, 1)) // SLOAD the array length from SELECTORS_SLOT

    //         // --- 1. Initialization ---

    //         // Initialize the 256-bit collision map on the stack
    //         let collisionMap := 0
    //         let numFacets := 0  // Actual number of unique facets collected
    //         let i := 0          // Selector index

    //         // --- 2. Main Loop: Iterate Selectors and Uniquely Collect Facets ---

    //         // Store the mapping slot pointer once for facetAndPosition[selector].facet slot calculation
    //         mstore(0x20, FACET_MAP_SLOT)

    //         for { } lt(i, selectorCount) { i := add(i, 1) } {

    //             // --- 2a. Load Selector and Find Facet Address ---

    //             // 1. Calculate selector's storage slot: i / 8 (8 selectors per 32 bytes)
    //             let selectorSlot := add(SELECTORS_BASE, div(i, 0x08))

    //             // 2. SLOAD: Load the 32-byte word containing up to 8 selectors
    //             let packedWord := sload(selectorSlot)

    //             // 3. Calculate Bit Offset: (i % 8) * 4 bytes * 8 bits
    //             // This is the shift amount needed to move the selector to the rightmost position (LSB).
    //             let shiftAmount := mul(mod(i, 0x08), 0x20)

    //             // 4. Extract Selector: Shift right and mask (bytes4 is 4 bytes/32 bits) and shift to the left
    //             // @dev no need to mask bytes4 selector with 0xffffffff as shr and shl cleans remaining bits to 0
    //             let selector := shl(0xe0, shr(shiftAmount, packedWord))

    //             // Calculate storage slot for facetAndPosition[selector].facet
    //             mstore(0x00, selector)
    //             // Reuses constantly stored FACET_MAP_SLOT at 0x20
    //             let facetDataSlot := keccak256(0x00, 0x40)

    //             // SLOAD 2: Load the facet address and clear out selector position
    //             let facetAddress := and(0xffffffffffffffffffffffffffffffffffffffff, sload(facetDataSlot))

    //             // --- 2b. O(1) Unique Check (Collision Map) ---

    //             let found := 0

    //             // Collision BitMask based on LSB of address
    //             let bitMask := shl(and(facetAddress, 0xff), 0x01)

    //             // Probabilistic O(1) Check: Check if the bit is set (collisionMap AND bitMask) != 0
    //             if iszero(iszero(and(collisionMap, bitMask))) {

    //                 // Fallback: Linear O(N) check (only runs on hash collision)
    //                 let facetIndex := 0
    //                 for {} lt(facetIndex, numFacets) { facetIndex := add(facetIndex, 1) } {
    //                     let elementPtr := add(FACETS_ELEMENTS_PTR, mul(facetIndex, 0x20))
    //                     if eq(mload(elementPtr), facetAddress) {
    //                         found := 1
    //                         break
    //                     }
    //                 }
    //             }

    //             // --- 2c. Conditional Append and Update Collision Map ---

    //             if iszero(found) {
    //                 // Not found: Append the facet

    //                 let newElementPtr := add(FACETS_ELEMENTS_PTR, mul(numFacets, 0x20))
    //                 mstore(newElementPtr, facetAddress)

    //                 // Update the collision map
    //                 collisionMap := or(collisionMap, bitMask)

    //                 numFacets := add(numFacets, 1)
    //             }
    //         }

    //         // --- 3. Finalize Return Array ---

    //         // Memory start for the return data
    //         let RETURN_PTR := 0x60

    //         // Store offset of the array in the return data
    //         mstore(RETURN_PTR, 0x20)

    //         // Store the actual number of unique facets in the array's length slot
    //         mstore(FACETS_ARRAY_PTR, numFacets)

    //         // Return memory segment
    //         let returnSize := add(0x40, mul(numFacets, 0x20))
    //         return(RETURN_PTR, returnSize)
    //     }
    // }

    function facetAddresses3() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        // Allocate the largest possible number of facet addresses
        allFacets = new address[](selectorsCount);

        // We create an in-memory mapping of the last byte of a facet address
        // to the facet address
        address[][256] memory map;
        // The key will hold the last byte of an ethereum address
        uint256 key;
        // If different facet addresses have the same last byte then we
        // store them in a bucket.
        address[] memory bucket;

        // This variable counts how many unique facets there are
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Assign to key the last byte of the facet
            key = uint160(facet) & 0xff;
            // Get an array of all facets that have the same last byte
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                if (bucket[bucketIndex] == facet) {
                    break;
                }
            }
            // Either we have looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if (bucketIndex == bucket.length) {
                // cheaper bucketIndex % 4 == 0
                if (bucketIndex & 3 == 0) {
                    // Allocating more bucket slots
                    address[] memory newBucket = new address[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                // Reset the bucket length
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
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

    function facetAddresses2() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        // Allocate the largest possible number of facet addresses
        allFacets = new address[](selectorsCount);

        // We create an in-memory mapping of the last byte of a facet address
        // to the facet address
        address[][256] memory map;
        // The key will hold the last byte of an ethereum address
        uint256 key;
        // If different facet addresses have the same last byte then we
        // store them in a bucket.
        address[] memory bucket;

        // This variable counts how many unique facets there are
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            // Assign to key the last byte of the facet
            key = uint160(facet) & 0xff;
            // Get an array of all facets that have the same last byte
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                address uniqueFacet = bucket[bucketIndex];
                // If uniqueFacet is address(0) then there is
                // an empty slot in the bucket array where
                // we can put the facet address
                if (uniqueFacet == address(0)) {
                    bucket[bucketIndex] = facet;
                    allFacets[numFacets] = facet;
                    unchecked {
                        numFacets++;
                    }
                    break;
                }
                if (uniqueFacet == facet) {
                    break;
                }
            }

            // Either we have looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if (bucketIndex == bucket.length) {
                // Create three additional slots in the bucket
                address[] memory newBucket = new address[](bucketIndex + 3);
                for (uint256 k; k < bucketIndex; k++) {
                    newBucket[k] = bucket[k];
                }
                bucket = newBucket;

                map[key] = bucket;
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

    // /// @notice Get all the facet addresses used by a diamond.
    // /// @return allFacets The facet addresses.
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

    // /// @notice Gets the facet address that supports the given selector.
    // /// @dev If facet is not found return address(0).
    // /// @param _functionSelector The function selector.
    // /// @return facet The facet address.
    // function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
    //     DiamondStorage storage s = getStorage();
    //     facet = s.facetAndPosition[_functionSelector].facet;
    // }
}
