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

   struct FacetInfo {
        address facet;
        bytes4[] selectors;
        uint256 count;
    }

    
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    


function facets13() external view returns (Facet[] memory allFacets) {
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
        uint256[] memory mapFacetInfoPointers;

        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;                          
            // Look for existing facet            
            key =  uint256(uint160(facet)) & 0xff;
            mapFacetInfoPointers = map[key];            
            uint256 mapIndex;
            for(; mapIndex < mapFacetInfoPointers.length; mapIndex++) {
                pointer = mapFacetInfoPointers[mapIndex];
                if(pointer == 0) {
                    bytes4[] memory selectorStorage = new bytes4[](20);
                    selectorStorage[0] = selector;
                    facetInfo = FacetInfo({facet: facet, selectors: selectorStorage, count: 1});                    
                    assembly ("memory-safe") {
                        pointer := facetInfo
                    }
                    mapFacetInfoPointers[mapIndex] = pointer;
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
            if(mapFacetInfoPointers.length == mapIndex) {
                // expand
                uint256[] memory newPointers = new uint256[](mapIndex + 3);
                for(uint256 k; k < mapIndex; k++) {
                    newPointers[k] = mapFacetInfoPointers[k];
                }
                mapFacetInfoPointers = newPointers;
                map[key] = mapFacetInfoPointers;
                
                bytes4[] memory selectorStorage = new bytes4[](20);
                selectorStorage[0] = selector;
                facetInfo = FacetInfo({facet: facet, selectors: selectorStorage, count: 1});                    
                assembly ("memory-safe") {
                    pointer := facetInfo
                }                
                mapFacetInfoPointers[mapIndex] = pointer;
                facetInfoPointers[numFacets] = pointer;
                unchecked {
                    numFacets++;    
                }                
            }                                     
        }

        allFacets = new Facet[](numFacets);

        // Allocate return array with exact size
        // allFacets = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {            
            pointer = facetInfoPointers[i];
            assembly ("memory-safe") {
                facetInfo := pointer
            }            
            allFacets[i].facet = facetInfo.facet;
            bytes4[] memory facetSelectors = facetInfo.selectors;
            uint256 facetSelectorCount = facetInfo.count;
            assembly {
                mstore(facetSelectors, facetSelectorCount)
            }
            allFacets[i].functionSelectors = facetSelectors;            
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
            
            if(facetIndex == numFacets) {
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
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorCount = selectors.length;
        uint256 numSelectors;
        facetSelectors = new bytes4[](selectorCount);
        // loop through function selectors
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            address facetAddress_ = s.facetAndPosition[selector].facet;
            if (_facet == facetAddress_) {
                facetSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        // Set the number of selectors in the array
        assembly ("memory-safe") {
            mstore(facetSelectors, numSelectors)
        }
    }

    function facetAddresses2() external view returns (address[] memory allFacets) {
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
            key =  uint256(uint160(facet)) & 0xff;
            bucket = map[key];
            bool found;          
            uint256 bucketIndex;
            for(; bucketIndex < bucket.length; bucketIndex++) {
                address bucketValue = bucket[bucketIndex];
                if(bucketValue == address(0)) {
                    break;
                }
                if(facet == bucketValue) {
                    found = true;
                    break;
                }
            }

            // If facet not found, add it            
            if(found == false) {
                // The facet key has never been used in the map
                if(bucketIndex == 0) {
                    bucket = new address[](3);
                }
                // Facet address was not found in all the mapFacetInfoPointers
                else if(bucketIndex == bucket.length) {                    
                    // expand
                    address[] memory newBucket = new address[](bucketIndex + 3);
                    for(uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                } // else we found an empty mapFacetInfoPointer (0)
                               
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
