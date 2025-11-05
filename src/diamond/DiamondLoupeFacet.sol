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
            key =  uint160(facet) & 0xff;
            // Get an array of all facets that have the same last byte
            bucket = map[key];            
            uint256 bucketIndex;
            for(; bucketIndex < bucket.length; bucketIndex++) {                
                address uniqueFacet = bucket[bucketIndex];
                // If uniqueFacet is address(0) then there is
                // an empty slot in the bucket array where 
                // we can put the facet address
                if(uniqueFacet == address(0)) {
                    bucket[bucketIndex] = facet;
                    allFacets[numFacets] = facet;
                    unchecked {
                        numFacets++;
                    }
                    break;                     
                }                
                if(uniqueFacet == facet) {
                    break;            
                }
            }

            // Either we have looped through all the available slots
            // in the bucket and found no match or
            // the bucket array was empty because the last address
            // byte hasn't been seen before
            if(bucketIndex == bucket.length) {                    
                // Create three additional slots in the bucket
                address[] memory newBucket = new address[](bucketIndex + 3);
                for(uint256 k; k < bucketIndex; k++) {
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

    /// @notice Struct to hold facet address and its function selectors
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    struct FacetInfo {
        address facet;
        bytes4[] selectors;
        // The actual number of selectors in "bytes4[] selectors"
        uint256 count;
    }

    /// @notice Gets all facets and their selectors.
    /// @return facetsAndSelectors Facet
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
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
            key =  uint160(facet) & 0xff;
            // Get an array of pointers to FacetInfo structs that have the same
            // facet last byte
            bucket = map[key];            
            uint256 bucketIndex;
            for(; bucketIndex < bucket.length; bucketIndex++) {
                pointer = bucket[bucketIndex];
                // If pointer == 0 then there is an empty slot in the bucket
                // that we will fill with a new pointer to a new FacetInfo struct
                if(pointer == 0) {                    
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
                if(facetInfo.facet == facet) {
                    // If there are no more empty facetInfo.selectors slots then we make more
                    if(facetInfo.count == facetInfo.selectors.length) {
                        // expand array
                        bytes4[] memory selectorStorage = new bytes4[](facetInfo.count + 20);
                        for(uint256 k; k < facetInfo.count; k++) {
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
            if(bucket.length == bucketIndex) {
                // Make more bucket slots
                uint256[] memory newPointers = new uint256[](bucketIndex + 3);
                for(uint256 k; k < bucketIndex; k++) {
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
}
