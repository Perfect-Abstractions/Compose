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

    function facets11() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = s.selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](selectorsCount);
        uint256 pointer;
        FacetInfo memory facetInfo;        

        uint256[512] memory map;
        // uint256[] memory map = new uint256[](1024);
        // uint256 bitmapSize = 128; // Start with minimum
        // unchecked {
        //     while (bitmapSize < selectorsCount / 2) {
        //         bitmapSize = bitmapSize << 1; // Double until optimal size
        //     }
        // }
        // console.log("Bitmap size:", bitmapSize);

        // uint256[] memory map = new uint256[](bitmapSize);

        uint256[] memory collisionFacetInfoPointers = new uint256[](20);                
        
        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;

            uint256 collisionIndex;
            bool collision;
                    
            // Look for existing facet            
            uint256 key =  uint256(uint160(facet)) >> 151;        
            pointer = map[key];
            // pointer has been found for the key
            if (pointer != 0) {
                collision = true;      
                assembly ("memory-safe") {
                    facetInfo := pointer
                }
                if(facetInfo.facet != facet) {   
                    // console.log("Collision detected for facet:", facet);                 
                    for(;collisionIndex < collisionFacetInfoPointers.length; collisionIndex++) {
                        pointer = collisionFacetInfoPointers[collisionIndex];
                        if(pointer == 0) {
                            break;
                        }
                        assembly ("memory-safe") {
                            facetInfo := pointer
                        }
                        if(facetInfo.facet == facet) {
                            break;
                        }
                        // console.log("Checking collision pointer at index:", collisionIndex, "facet:", facetInfo.facet);
                    }
                    if(collisionIndex == collisionFacetInfoPointers.length) {
                        // expand
                        uint256[] memory newPointers = new uint256[](collisionIndex + 20);
                        for(uint256 k; k < collisionIndex; k++) {
                            newPointers[k] = collisionFacetInfoPointers[k];
                        }
                        collisionFacetInfoPointers = newPointers;
                        pointer = 0;
                        console.log("Expanded collisionFacetInfoPointers to length:", collisionFacetInfoPointers.length);
                    }                    
                }                
            }            
            // if facet found
            if(pointer != 0) {
                if(facetInfo.count == facetInfo.selectors.length) {
                    // expand array
                    bytes4[] memory newSelectors = new bytes4[](facetInfo.count + 20);
                    for(uint256 k; k < facetInfo.count; k++) {
                        newSelectors[k] = facetInfo.selectors[k];
                    }
                    facetInfo.selectors = newSelectors;
                }
                facetInfo.selectors[facetInfo.count] = selector;
                facetInfo.count++;  
            } else {                
                bytes4[] memory newSelectors = new bytes4[](20);
                newSelectors[0] = selector;
                facetInfo = FacetInfo({facet: facet, selectors: newSelectors, count: 1});
                assembly ("memory-safe") {
                    pointer := facetInfo
                }
                if(collision) {                    
                    console.log("Collision detected for facet:", facet, "at index:", collisionIndex);
                    collisionFacetInfoPointers[collisionIndex] = pointer;
                } else {
                    map[key] = pointer;
                }
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

     function facets10() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = s.selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](selectorsCount);
        uint256 pointer;
        FacetInfo memory facetInfo;        

        uint256[256] memory map;
        // uint256 bitmapSize = 128; // Start with minimum
        // unchecked {
        //     while (bitmapSize < selectorsCount / 2) {
        //         bitmapSize = bitmapSize << 1; // Double until optimal size
        //     }
        // }
        //console.log("Bitmap size:", bitmapSize);

        //uint256[] memory map = new uint256[](bitmapSize);

        uint256[] memory collisionFacetInfoPointers = new uint256[](20);                
        
        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;

            uint256 collisionIndex;
            bool collision;

            // Look for existing facet            
            uint256 key =  uint256(uint160(facet)) >> 152;            
            pointer = map[key];
            // pointer has been found for the key
            if (pointer != 0) {
                collision = true;      
                assembly ("memory-safe") {
                    facetInfo := pointer
                }
                if(facetInfo.facet != facet) {   
                    // console.log("Collision detected for facet:", facet);                 
                    for(;collisionIndex < collisionFacetInfoPointers.length; collisionIndex++) {
                        pointer = collisionFacetInfoPointers[collisionIndex];
                        if(pointer == 0) {
                            break;
                        }
                        assembly ("memory-safe") {
                            facetInfo := pointer
                        }
                        if(facetInfo.facet == facet) {
                            break;
                        }
                        // console.log("Checking collision pointer at index:", collisionIndex, "facet:", facetInfo.facet);
                    }
                    if(collisionIndex == collisionFacetInfoPointers.length) {
                        // expand
                        uint256[] memory newPointers = new uint256[](collisionIndex + 20);
                        for(uint256 k; k < collisionIndex; k++) {
                            newPointers[k] = collisionFacetInfoPointers[k];
                        }
                        collisionFacetInfoPointers = newPointers;
                        pointer = 0;
                        console.log("Expanded collisionFacetInfoPointers to length:", collisionFacetInfoPointers.length);
                    }                    
                }                
            }            
            // if facet found
            if(pointer != 0) {
                if(facetInfo.count == facetInfo.selectors.length) {
                    // expand array
                    bytes4[] memory newSelectors = new bytes4[](facetInfo.count + 20);
                    for(uint256 k; k < facetInfo.count; k++) {
                        newSelectors[k] = facetInfo.selectors[k];
                    }
                    facetInfo.selectors = newSelectors;
                }
                facetInfo.selectors[facetInfo.count] = selector;
                facetInfo.count++;  
            } else {                
                bytes4[] memory newSelectors = new bytes4[](20);
                newSelectors[0] = selector;
                facetInfo = FacetInfo({facet: facet, selectors: newSelectors, count: 1});
                assembly ("memory-safe") {
                    pointer := facetInfo
                }
                if(collision) {                    
                    console.log("Collision detected for facet:", facet, "at index:", collisionIndex);
                    collisionFacetInfoPointers[collisionIndex] = pointer;
                } else {
                    map[key] = pointer;
                }
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
    function facets12() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = s.selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](selectorsCount);
        uint256 pointer;
        FacetInfo memory facetInfo;

        uint256[][256] memory map;
                
        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;                        
            // Look for existing facet            
            uint256 key =  uint256(uint160(facet)) & 0xff;
            uint256[] memory mapFacetInfoPointers;
            mapFacetInfoPointers = map[key];            
            uint256 mapIndex = 0; 
            for(; mapIndex < mapFacetInfoPointers.length; mapIndex++) {
                pointer = mapFacetInfoPointers[mapIndex];
                if(pointer == 0) {
                    break;
                }
                assembly ("memory-safe") {
                    facetInfo := pointer
                }
                if(facetInfo.facet == facet) {
                    if(facetInfo.count == facetInfo.selectors.length) {
                        // expand array
                        bytes4[] memory newSelectors = new bytes4[](facetInfo.count + 20);
                        for(uint256 k; k < facetInfo.count; k++) {
                            newSelectors[k] = facetInfo.selectors[k];
                        }
                        facetInfo.selectors = newSelectors;
                    }
                    facetInfo.selectors[facetInfo.count] = selector;
                    facetInfo.count++;                    
                    break;
                }
            }

            // There are 3 ways a facet is not found:
            // 1. The facet key has never been used in the map. 
            //    Therefore mapIndex is 0 and mapFacetInfoPointers.length is 0.
            // 2. The facet key has been used, ane we started iterating over the
            //    mapFacetInfoPointers and we found an empty one (0).
            // 3. The facet key has been used, and we iterated over all the mapFacetInfoPointers
            //    and the facet address wasn't found.            
            
            // If facet not found, add it
            if (mapIndex == mapFacetInfoPointers.length || pointer == 0) {
                // The facet key has never been used in the map
                if(mapIndex == 0) {
                    mapFacetInfoPointers = new uint256[](3);
                }
                // Facet address was not found in all the mapFacetInfoPointers
                else if(mapIndex == mapFacetInfoPointers.length) {                    
                    // expand
                    uint256[] memory newPointers = new uint256[](mapIndex + 3);
                    for(uint256 k; k < mapIndex; k++) {
                        newPointers[k] = mapFacetInfoPointers[k];
                    }
                    mapFacetInfoPointers = newPointers;
                } // else we found an empty mapFacetInfoPointer (0)
                               
                map[key] = mapFacetInfoPointers;
                bytes4[] memory newSelectors = new bytes4[](20);
                newSelectors[0] = selector;
                facetInfo = FacetInfo({facet: facet, selectors: newSelectors, count: 1});
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

    function facets9() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = s.selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](selectorsCount);
        uint256 pointer;
        FacetInfo memory facetInfo;

        uint256[][256] memory map;
                
        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;                        
            // Look for existing facet            
            uint256 key =  uint256(uint160(facet)) & 0xff;
            uint256[] memory mapFacetInfoPointers;
            mapFacetInfoPointers = map[key];            
            uint256 mapIndex = 0; 
            for(; mapIndex < mapFacetInfoPointers.length; mapIndex++) {
                pointer = mapFacetInfoPointers[mapIndex];
                if(pointer == 0) {
                    break;
                }
                assembly ("memory-safe") {
                    facetInfo := pointer
                }
                if(facetInfo.facet == facet) {
                    if(facetInfo.count == facetInfo.selectors.length) {
                        // expand array
                        bytes4[] memory newSelectors = new bytes4[](facetInfo.count + 20);
                        for(uint256 k; k < facetInfo.count; k++) {
                            newSelectors[k] = facetInfo.selectors[k];
                        }
                        facetInfo.selectors = newSelectors;
                    }
                    facetInfo.selectors[facetInfo.count] = selector;
                    facetInfo.count++;                    
                    break;
                }
            }

            // There are 3 ways a facet is not found:
            // 1. The facet key has never been used in the map. 
            //    Therefore mapIndex is 0 and mapFacetInfoPointers.length is 0.
            // 2. The facet key has been used, ane we started iterating over the
            //    mapFacetInfoPointers and we found an empty one (0).
            // 3. The facet key has been used, and we iterated over all the mapFacetInfoPointers
            //    and the facet address wasn't found.            
            
            // If facet not found, add it
            if (mapIndex == mapFacetInfoPointers.length || pointer == 0) {
                // The facet key has never been used in the map
                if(mapIndex == 0) {
                    mapFacetInfoPointers = new uint256[](3);
                }
                // Facet address was not found in all the mapFacetInfoPointers
                else if(mapIndex == mapFacetInfoPointers.length) {                    
                    // expand
                    uint256[] memory newPointers = new uint256[](mapIndex + 3);
                    for(uint256 k; k < mapIndex; k++) {
                        newPointers[k] = mapFacetInfoPointers[k];
                    }
                    mapFacetInfoPointers = newPointers;
                } // else we found an empty mapFacetInfoPointer (0)
                               
                map[key] = mapFacetInfoPointers;
                bytes4[] memory newSelectors = new bytes4[](20);
                newSelectors[0] = selector;
                facetInfo = FacetInfo({facet: facet, selectors: newSelectors, count: 1});
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


    function facets5() external view returns (Facet[] memory allFacets) {
       DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 maxFacetInfoPointers = selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](maxFacetInfoPointers);
        uint256 pointer;
        FacetInfo memory facetInfo;
                
        // count unique facets
        uint256 numFacets;             
        
        // Count unique facets and their selectors
        for (uint256 i; i < maxFacetInfoPointers; i++) {
            address facet = s.facetAndPosition[selectors[i]].facet;
                        
            // Look for existing facet
            uint256 facetIndex;
            for (; facetIndex < numFacets; facetIndex++) {                
                pointer = facetInfoPointers[facetIndex];
                assembly ("memory-safe") {
                    facetInfo := pointer
                }
                if (facetInfo.facet == facet) {                    
                    if(facetInfo.count == facetInfo.selectors.length) {
                        // expand array
                        bytes4[] memory newSelectors = new bytes4[](facetInfo.count + 20);
                        for(uint256 j; j < facetInfo.count; j++) {
                            newSelectors[j] = facetInfo.selectors[j];
                        }
                        facetInfo.selectors = newSelectors;
                    }
                    facetInfo.selectors[facetInfo.count] = selectors[i];
                    facetInfo.count++;
                    break;
                }
            }
            
            // If facet not found, add it
            if (facetIndex == numFacets) {
                bytes4[] memory newSelectors = new bytes4[](20);
                newSelectors[0] = selectors[i];
                facetInfo = FacetInfo({facet: facet, selectors: newSelectors, count: 1});
                assembly ("memory-safe") {
                    pointer := facetInfo
                }
                facetInfoPointers[facetIndex] = pointer;
                numFacets++;
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

    // struct FacetInfo {
    //     address facet;
    //     uint256 start;
    //     uint256 count;
    // }

    
//    struct FacetInfo2 {
//         address facet;
//         uint256 selectorStartPointer;
//         uint256 selectorEndPointer;
//         uint256 count;
//     }
    
  
//     // Keep a list pointer implementation of facet selectors       
//     function facets8() external view returns (Facet[] memory allFacets) {
//         DiamondStorage storage s = getStorage();
//         bytes4[] memory selectors = s.selectors;
//         uint256 maxFacetInfoPointers = selectors.length;
    
//         // This is an array of pointers to FacetInfo structs which don't exist yet.                
//         // We will fill in the actual FacetInfo structs as we go.
//         uint256[] memory facetInfoPointers = new uint256[](maxFacetInfoPointers);
//         uint256 facetInfoPointer;
//         FacetInfo2 memory facetInfo;

//         uint256 selectorValuePointer;
//         uint256 selectorNextPointer;
                
//         // count unique facets
//         uint256 numFacets;             
        
//         // Count unique facets and their selectors
//         for (uint256 i; i < maxFacetInfoPointers; i++) {
//             bytes4 selector = selectors[i];
//             address facet = s.facetAndPosition[selector].facet;
                        
//             // Look for existing facet
//             uint256 facetIndex;
//             for (; facetIndex < numFacets; facetIndex++) {                
//                 facetInfoPointer = facetInfoPointers[facetIndex];
//                 assembly ("memory-safe") {
//                     facetInfo := facetInfoPointer
//                 }
//                 if (facetInfo.facet == facet) {
//                     selectorNextPointer = facetInfo.selectorEndPointer;
//                     assembly ("memory-safe") {
//                         selectorValuePointer := mload(0x40)
//                         mstore(selectorValuePointer, selector)
//                         mstore(selectorNextPointer, selectorValuePointer)
//                         selectorNextPointer := add(0x20, selectorValuePointer)                    
//                         mstore(0x40, add(0x20, selectorNextPointer))
//                     }
//                     facetInfo.selectorEndPointer = selectorNextPointer;
//                     facetInfo.count++;          
//                     break;
//                 }
//             }            
            
//             // If facet not found, add it
//             if (facetIndex == numFacets) {
//                 unchecked {                 
//                     numFacets++;    
//                 }                         
//                 assembly ("memory-safe") {
//                     selectorValuePointer := mload(0x40)
//                     mstore(selectorValuePointer, selector)                    
//                     selectorNextPointer := add(0x20, selectorValuePointer)                    
//                     mstore(0x40, add(0x20, selectorNextPointer))
//                 }                                
//                 facetInfo = FacetInfo2({
//                     facet: facet,
//                     selectorStartPointer: selectorValuePointer,
//                     selectorEndPointer: selectorNextPointer,
//                     count: 1
//                 });
//                 assembly ("memory-safe") {
//                     facetInfoPointer := facetInfo
//                 }
//                 facetInfoPointers[facetIndex] = facetInfoPointer;
//             } 
//         }

//         allFacets = new Facet[](numFacets);
        
//         // Allocate return array with exact size
//         // allFacets = new Facet[](numFacets);
//         for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {            
//             facetInfoPointer = facetInfoPointers[facetIndex];
//             assembly ("memory-safe") {
//                 facetInfo := facetInfoPointer
//             }            
//             allFacets[facetIndex].facet = facetInfo.facet;
//             uint256 selectorPointer = facetInfo.selectorStartPointer;
//             uint256 count = facetInfo.count;
//             allFacets[facetIndex].functionSelectors = new bytes4[](count);            
//             for(uint256 i; i < facetInfo.count; i++) {
//                 bytes4 selector;
//                 assembly ("memory-safe") {
//                     selector := mload(selectorPointer)
//                     selectorPointer := mload(add(selectorPointer, 0x20))
//                 }
//                 allFacets[facetIndex].functionSelectors[i] = selector;
//             }            
//         }        
//     }
    

   
    
    
    

    // function facets2() external view returns (Facet[] memory allFacets) {
    //     DiamondStorage storage s = getStorage();
    //     bytes4[] memory selectors = s.selectors;
    //     uint256 selectorCount = selectors.length;
    
        
    //     // First pass: count unique facets
    //     uint256 numFacets;
    //     address[] memory uniqueFacets = new address[](selectorCount);
    //     uint256[] memory selectorsByFacet = new uint256[](selectorCount);
        
    //     // Count unique facets and their selectors
    //     for (uint256 i; i < selectorCount; i++) {
    //         address facet = s.facetAndPosition[selectors[i]].facet;
            
    //         // Look for existing facet
    //         uint256 facetIndex;
    //         for (; facetIndex < numFacets; facetIndex++) {
    //             if (uniqueFacets[facetIndex] == facet) {
    //                 selectorsByFacet[facetIndex]++;
    //                 break;
    //             }
    //         }
            
    //         // If facet not found, add it
    //         if (facetIndex == numFacets) {
    //             uniqueFacets[numFacets] = facet;
    //             selectorsByFacet[numFacets] = 1;
    //             numFacets++;
    //         }
    //     }
        
    //     // Allocate return array with exact size
    //     allFacets = new Facet[](numFacets);
        
    //     // Initialize facet arrays with correct sizes
    //     for (uint256 i; i < numFacets; i++) {
    //         allFacets[i].facet = uniqueFacets[i];
    //         allFacets[i].functionSelectors = new bytes4[](selectorsByFacet[i]);
    //     }
        
    //     // // Reset selector counts for use as indices
    //     // for (uint256 i; i < numFacets; i++) {
    //     //     selectorsByFacet[i] = 0;
    //     // }
        
    //     // Second pass: populate selector arrays
    //     for (uint256 i; i < selectorCount; i++) {
    //         bytes4 selector = selectors[i];
    //         address facet = s.facetAndPosition[selector].facet;
            
    //         // Find the facet index
    //         for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
    //             if (allFacets[facetIndex].facet == facet) {
    //                 allFacets[facetIndex].functionSelectors[--selectorsByFacet[facetIndex]] = selector;
    //                 break;
    //             }
    //         }
    //     }
    // }

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
    // function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
    //     DiamondStorage storage s = getStorage();
    //     uint256 selectorCount = s.selectors.length;
    //     uint256 numSelectors;
    //     facetSelectors = new bytes4[](selectorCount);
    //     // loop through function selectors
    //     for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
    //         bytes4 selector = s.selectors[selectorIndex];
    //         address facetAddress_ = s.facetAndPosition[selector].facet;
    //         if (_facet == facetAddress_) {
    //             facetSelectors[numSelectors] = selector;
    //             numSelectors++;
    //         }
    //     }
    //     // Set the number of selectors in the array
    //     assembly ("memory-safe") {
    //         mstore(facetSelectors, numSelectors)
    //     }
    // }

    // /// @notice Get all the facet addresses used by a diamond.
    // /// @return allFacets The facet addresses.
    // function facetAddresses() external view returns (address[] memory allFacets) {
    //     DiamondStorage storage s = getStorage();
    //     uint256 selectorCount = s.selectors.length;
    //     // create an array set to the maximum size possible
    //     allFacets = new address[](selectorCount);
    //     uint256 numFacets;
    //     // loop through function selectors
    //     for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
    //         bytes4 selector = s.selectors[selectorIndex];
    //         address facetAddress_ = s.facetAndPosition[selector].facet;
    //         bool continueLoop = false;
    //         // see if we have collected the address already and break out of loop if we have
    //         for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
    //             if (facetAddress_ == allFacets[facetIndex]) {
    //                 continueLoop = true;
    //                 break;
    //             }
    //         }
    //         // continue loop if we already have the address
    //         if (continueLoop) {
    //             continueLoop = false;
    //             continue;
    //         }
    //         // include address
    //         allFacets[numFacets] = facetAddress_;
    //         numFacets++;
    //     }
    //     // Set the number of facet addresses in the array
    //     assembly ("memory-safe") {
    //         mstore(allFacets, numFacets)
    //     }
    // }

    // /// @notice Gets the facet address that supports the given selector.
    // /// @dev If facet is not found return address(0).
    // /// @param _functionSelector The function selector.
    // /// @return facet The facet address.
    // function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
    //     DiamondStorage storage s = getStorage();
    //     facet = s.facetAndPosition[_functionSelector].facet;
    // }
}
