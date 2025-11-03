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
        facetSelectors = new bytes4[](0);
        // loop through function selectors
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = selectors[i];
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
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        address[] memory uniqueFacets = new address[](selectorsCount);
        
        address[][256] memory map;
        uint256 key;
        address[] memory bucket;
                        
        // count unique facets
        uint256 numFacets;            
        // Count unique facets and their selectors 

         for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;                        
            // Look for existing facet            
            key =  uint160(facet) & 0xff;
            bucket = map[key];            
            uint256 bucketIndex;
            for(; bucketIndex < bucket.length; bucketIndex++) {
                address uniqueFacet = bucket[bucketIndex];
                if(uniqueFacet == address(0)) {
                    bucket[bucketIndex] = facet;
                    uniqueFacets[numFacets] = facet;
                    unchecked {
                        numFacets++;
                    }
                    break;                     
                }
                if(uniqueFacet == facet) {
                    break;            
                }
            }

            if(bucketIndex == bucket.length) {                    
                // expand
                address[] memory newBucket = new address[](bucketIndex + 3);
                for(uint256 k; k < bucketIndex; k++) {
                    newBucket[k] = bucket[k];
                }
                bucket = newBucket;
                            
                map[key] = bucket;
                bucket[bucketIndex] = facet;
                uniqueFacets[numFacets] = facet;
                unchecked {
                    numFacets++;
                }     
            }                       
         }
         assembly ("memory-safe") {
            mstore(uniqueFacets, numFacets)
         }
         allFacets = uniqueFacets;
    }

    /// @notice Struct to hold facet address and its function selectors
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    struct FacetInfo {
        address facet;
        bytes4[] selectors;
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
        uint256 pointer;
        FacetInfo memory facetInfo;

        uint256[][256] memory map;
        uint256 key;        
        uint256[] memory bucket;

        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;                          
            // Look for existing facet            
            key =  uint160(facet) & 0xff;
            bucket = map[key];            
            uint256 bucketIndex;
            for(; bucketIndex < bucket.length; bucketIndex++) {
                pointer = bucket[bucketIndex];
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
                assembly ("memory-safe") {
                    facetInfo := pointer
                }            
                if(facetInfo.facet == facet) {                    
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

            // facet was not found and looped through all options
            // Or there were no options
            if(bucket.length == bucketIndex) {
                // expand
                uint256[] memory newPointers = new uint256[](bucketIndex + 3);
                for(uint256 k; k < bucketIndex; k++) {
                    newPointers[k] = bucket[k];
                }
                bucket = newPointers;
                map[key] = bucket;
                
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

        facetsAndSelectors = new Facet[](numFacets);
        
        // Allocate return array with exact size
        // allFacets = new Facet[](numFacets);
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
