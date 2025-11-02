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
    

    // function facets4() external view returns (Facet[] memory allFacets) {
    //     DiamondStorage storage s = getStorage();
    //     uint256 selectorCount = s.selectors.length;
    //     if (selectorCount == 0) {
    //         return new Facet[](0);
    //     }

    //     // BITMAP-BASED DEDUPLICATION SETUP
    //     // Calculate optimal bitmap size: power of 2, roughly selectorCount / 4
    //     // This gives good balance between memory and collision rate
    //     uint256 bitmapSize = 16; // Start with minimum
    //     unchecked {
    //         while (bitmapSize < selectorCount / 4 && bitmapSize < 256) {
    //             bitmapSize = bitmapSize << 1; // Double until optimal size
    //         }
    //     }

    //     // Bitmap: maps address hash → facet address (0 = empty slot)
    //     address[] memory bitmap = new address[](bitmapSize);

    //     // Collision handling: small array for hash collisions
    //     address[] memory collisionAddrs = new address[](selectorCount);
    //     uint256 collisionCount;

    //     // Main facet tracking arrays
    //     address[] memory facetsList = new address[](selectorCount);
    //     uint256[] memory selectorCounts = new uint256[](selectorCount);
    //     uint256 numFacets;

    //     unchecked {
    //         // PASS 1: Count selectors per facet using bitmap deduplication
    //         for (uint256 i; i < selectorCount; i++) {
    //             bytes4 selector = s.selectors[i];
    //             address facetAddr = s.facetAndPosition[selector].facet;

    //             // Hash address to bitmap index using modulo
    //             // This provides O(1) lookup for most cases
    //             uint256 hash = uint256(uint160(facetAddr)) % bitmapSize;

    //             // Check bitmap slot
    //             if (bitmap[hash] == address(0)) {
    //                 // Empty slot - new unique facet
    //                 bitmap[hash] = facetAddr;
    //                 facetsList[numFacets] = facetAddr;
    //                 selectorCounts[numFacets] = 1;
    //                 numFacets++;
    //             } else if (bitmap[hash] == facetAddr) {
    //                 // Exact match - find facet and increment
    //                 // Linear search through facets (small list)
    //                 for (uint256 j; j < numFacets; j++) {
    //                     if (facetsList[j] == facetAddr) {
    //                         selectorCounts[j]++;
    //                         break;
    //                     }
    //                 }
    //             } else {
    //                 // Collision - different facet, same hash
    //                 // Check collision list first
    //                 bool foundInCollisions;
    //                 for (uint256 k; k < collisionCount; k++) {
    //                     if (collisionAddrs[k] == facetAddr) {
    //                         // Find in main list and increment
    //                         for (uint256 j; j < numFacets; j++) {
    //                             if (facetsList[j] == facetAddr) {
    //                                 selectorCounts[j]++;
    //                                 break;
    //                             }
    //                         }
    //                         foundInCollisions = true;
    //                         break;
    //                     }
    //                 }

    //                 if (!foundInCollisions) {
    //                     // New colliding facet - add to both lists
    //                     collisionAddrs[collisionCount] = facetAddr;
    //                     collisionCount++;
    //                     facetsList[numFacets] = facetAddr;
    //                     selectorCounts[numFacets] = 1;
    //                     numFacets++;
    //                 }
    //             }
    //         }
    //     }

    //     // PASS 2: Allocate exact-size return structure
    //     allFacets = new Facet[](numFacets);

    //     unchecked {
    //         for (uint256 i; i < numFacets; i++) {
    //             allFacets[i].facet = facetsList[i];
    //             allFacets[i].functionSelectors = new bytes4[](selectorCounts[i]);
    //             // Reset counts for use as insertion indices
    //             selectorCounts[i] = 0;
    //         }
    //     }

    //     unchecked {
    //         // PASS 3: Populate selector arrays using bitmap for fast lookup
    //         for (uint256 i; i < selectorCount; i++) {
    //             bytes4 selector = s.selectors[i];
    //             address facetAddr = s.facetAndPosition[selector].facet;

    //             // Find facet index (reuse bitmap for fast lookup)
    //             uint256 hash = uint256(uint160(facetAddr)) % bitmapSize;

    //             // Quick path: check if bitmap slot matches
    //             bool found;
    //             if (bitmap[hash] == facetAddr) {
    //                 // Find in facet list
    //                 for (uint256 j; j < numFacets; j++) {
    //                     if (allFacets[j].facet == facetAddr) {
    //                         uint256 pos = selectorCounts[j];
    //                         allFacets[j].functionSelectors[pos] = selector;
    //                         selectorCounts[j]++;
    //                         found = true;
    //                         break;
    //                     }
    //                 }
    //             }

    //             // Collision path: search facet list directly
    //             if (!found) {
    //                 for (uint256 j; j < numFacets; j++) {
    //                     if (allFacets[j].facet == facetAddr) {
    //                         uint256 pos = selectorCounts[j];
    //                         allFacets[j].functionSelectors[pos] = selector;
    //                         selectorCounts[j]++;
    //                         break;
    //                     }
    //                 }
    //             }
    //         }
    //     }
    // }

    // function facets2Opt() external view returns (Facet[] memory allFacetsAndSelectors) {
    //     DiamondStorage storage s = getStorage();
    //     bytes4[] memory selectors = s.selectors;
    //     uint256 selectorCount = selectors.length;
    
    //     // First pass: count unique facets
    //     uint256 numFacets;        
    //     uint256 uniqueFacetsArray;
    //     uint256 uniqueFacetAndCount;

    //     assembly ("memory-safe") {
    //         // Set uniqueFacetsArray position in memory
    //         uniqueFacetsArray := mload(0x40)            
    //     }
        
    //     // Count unique facets and their selectors
    //     for (uint256 i; i < selectorCount; i++) {
    //         address facet = s.facetAndPosition[selectors[i]].facet;
            
    //         // Look for existing facet
    //         uint256 facetIndex;
    //         for (; facetIndex < numFacets; facetIndex++) {                      
    //             assembly ("memory-safe") {
    //                 // Load facet address from uniqueFacets array
    //                 uniqueFacetAndCount := mload(add(uniqueFacetsArray, mul(facetIndex, 0x20)))
    //             }
    //             if (address(uint160(uniqueFacetAndCount >> 0x20)) == facet) {
    //                 assembly ("memory-safe") {
    //                     // Increment the selector count for this facet in uniqueFacets array
    //                     mstore(
    //                         add(uniqueFacetsArray, mul(facetIndex, 0x20)), 
    //                         add(uniqueFacetAndCount, 1)
    //                     )
    //                 }
    //                 break;
    //             }
    //         }            
    //         // If facet not found, add it
    //         if (facetIndex == numFacets) {                                
    //             assembly ("memory-safe") {
    //                 // Combine facet address and selectors count into a single value to store in uniqueFacetsArray
    //                 let facetAndSelectorsCount := or(shl(0x20, facet), 1)
    //                 // Store in uniqueFacets array
    //                 mstore(add(uniqueFacetsArray, mul(facetIndex, 0x20)), facetAndSelectorsCount)
    //             }
    //             numFacets++;
    //         }
    //     }
    //     assembly ("memory-safe") {
    //         // Move the free memory pointer after the uniqueFacetsArray
    //         mstore(0x40, add(0x20, add(uniqueFacetsArray, mul(numFacets, 0x20))))
    //     }

        
    //     // Allocate return array with exact size
    //     allFacetsAndSelectors = new Facet[](numFacets);
        
    //     // Initialize facet arrays with correct sizes
    //     for (uint256 i; i < numFacets; i++) {
    //         assembly {
    //             uniqueFacetAndCount := mload(add(uniqueFacetsArray, mul(i, 0x20)))
    //         }
    //         allFacetsAndSelectors[i].facet = address(uint160(uniqueFacetAndCount >> 0x20));
    //         allFacetsAndSelectors[i].functionSelectors = new bytes4[](uniqueFacetAndCount & 0xFFFFFFFF);
    //     }
        
    //     // Second pass: populate selector arrays
    //     for (uint256 i; i < selectorCount; i++) {
    //         bytes4 selector = selectors[i];
    //         address facet = s.facetAndPosition[selector].facet;
            
    //         // Find the facet index
    //         for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
    //             if (allFacetsAndSelectors[facetIndex].facet == facet) {
    //                 uint256 selectorIndex;
    //                 assembly ("memory-safe") {
    //                     // Load the current selector count for this facet from uniqueFacets array
    //                     selectorIndex := sub(mload(add(uniqueFacetsArray, mul(facetIndex, 0x20))), 1)
    //                     mstore(add(uniqueFacetsArray, mul(facetIndex, 0x20)), selectorIndex)
    //                     selectorIndex := and(selectorIndex, 0xFFFFFFFF) // Mask to get the selector index for this facet
    //                 }
    //                 allFacetsAndSelectors[facetIndex].functionSelectors[selectorIndex] = selector;
    //                 break;
    //             }
    //         }
    //     }
      
    // }

    

// Temporary struct to hold facet info

   struct FacetInfo {
        address facet;
        bytes4[] selectors;
        uint256 count;
    }

    struct FacetInfo {
        address facet;
        bytes4[] selectors;
        uint256 count;
    }
    
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    function facets9() external view returns (Facet[] memory allFacets) {
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

    
   struct FacetInfo2 {
        address facet;
        uint256 selectorStartPointer;
        uint256 selectorEndPointer;
        uint256 count;
    }
    
  
         
    function facets8() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 maxFacetInfoPointers = selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        uint256[] memory facetInfoPointers = new uint256[](maxFacetInfoPointers);
        uint256 facetInfoPointer;
        FacetInfo2 memory facetInfo;

        uint256 selectorValuePointer;
        uint256 selectorNextPointer;
                
        // count unique facets
        uint256 numFacets;             
        
        // Count unique facets and their selectors
        for (uint256 i; i < maxFacetInfoPointers; i++) {
            bytes4 selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
                        
            // Look for existing facet
            uint256 facetIndex;
            for (; facetIndex < numFacets; facetIndex++) {                
                facetInfoPointer = facetInfoPointers[facetIndex];
                assembly ("memory-safe") {
                    facetInfo := facetInfoPointer
                }
                if (facetInfo.facet == facet) {
                    selectorNextPointer = facetInfo.selectorEndPointer;
                    assembly ("memory-safe") {
                        selectorValuePointer := mload(0x40)
                        mstore(selectorValuePointer, selector)
                        mstore(selectorNextPointer, selectorValuePointer)
                        selectorNextPointer := add(0x20, selectorValuePointer)                    
                        mstore(0x40, add(0x20, selectorNextPointer))
                    }
                    facetInfo.selectorEndPointer = selectorNextPointer;
                    facetInfo.count++;          
                    break;
                }
            }            
            
            // If facet not found, add it
            if (facetIndex == numFacets) {
                unchecked {                 
                    numFacets++;    
                }                         
                assembly ("memory-safe") {
                    selectorValuePointer := mload(0x40)
                    mstore(selectorValuePointer, selector)                    
                    selectorNextPointer := add(0x20, selectorValuePointer)                    
                    mstore(0x40, add(0x20, selectorNextPointer))
                }                                
                facetInfo = FacetInfo2({
                    facet: facet,
                    selectorStartPointer: selectorValuePointer,
                    selectorEndPointer: selectorNextPointer,
                    count: 1
                });
                assembly ("memory-safe") {
                    facetInfoPointer := facetInfo
                }
                facetInfoPointers[facetIndex] = facetInfoPointer;
            } 
        }

        allFacets = new Facet[](numFacets);
        
        // Allocate return array with exact size
        // allFacets = new Facet[](numFacets);
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {            
            facetInfoPointer = facetInfoPointers[facetIndex];
            assembly ("memory-safe") {
                facetInfo := facetInfoPointer
            }            
            allFacets[facetIndex].facet = facetInfo.facet;
            uint256 selectorPointer = facetInfo.selectorStartPointer;
            uint256 count = facetInfo.count;
            allFacets[facetIndex].functionSelectors = new bytes4[](count);            
            for(uint256 i; i < facetInfo.count; i++) {
                bytes4 selector;
                assembly ("memory-safe") {
                    selector := mload(selectorPointer)
                    selectorPointer := mload(add(selectorPointer, 0x20))
                }
                allFacets[facetIndex].functionSelectors[i] = selector;
            }            
        }        
    }
    

        // this is flawed
      /// @notice Gas-optimized, compiler-safe facets implementation
    function facets7() external view returns (Facet[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 totalSelectors = selectors.length;

        // Pre-allocate primitive helpers sized to worst-case (each selector a unique facet)
        address[] memory facetOf = new address[](totalSelectors);
        uint256[] memory counts = new uint256[](totalSelectors);
        uint256[] memory starts = new uint256[](totalSelectors);
        bytes4[] memory selectorsByFacet = new bytes4[](totalSelectors);

        uint256 numFacets;
        uint256 nextPos;

        // Loop through all selectors, group by facet using a linear search over facetAddrs.
        // Linear search is O(n^2) worst-case but avoids heavy dynamic memory allocations.
        for (uint256 i = 0; i < totalSelectors; i++) {
            bytes4 selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            
            uint256 facetIndex = 0;
            for (facetIndex; facetIndex < numFacets; facetIndex++) {
                if (facetOf[facetIndex] == facet) {
                    break;
                }
            }

            // If facet not found, add it
            if (facetIndex == numFacets) {
                // new facet: record start position
                facetOf[numFacets] = facet;
                starts[numFacets] = nextPos;                
                numFacets++;
            }

            // append selector into flat buffer
            selectorsByFacet[nextPos] = selector;
            unchecked {
                nextPos++;
                counts[facetIndex]++;
            }
                        
        }

        // Build return array with exact sizes
        allFacets = new Facet[](numFacets);
        for (uint256 facetIndex; facetIndex < numFacets; facetIndex++) {
            uint256 count = counts[facetIndex];
            bytes4[] memory selectorsForFacet = new bytes4[](count);
            uint256 start = starts[facetIndex];
            // copy from flat buffer into exact-sized array
            for (uint256 j = 0; j < count; ++j) {
                selectorsForFacet[j] = selectorsByFacet[start + j];
            }
            allFacets[facetIndex].facet = facetOf[facetIndex];
            allFacets[facetIndex].functionSelectors = selectorsForFacet;
        }
    }
    

    
    
    
    // function facets3() external view returns (Facet[] memory allFacets) {
    //    DiamondStorage storage s = getStorage();
    //     bytes4[] memory selectors = s.selectors;
    //     uint256 maxFacetInfoPointers = selectors.length;
    
    //     // This is essentially an array of pointers to FacetInfo structs which don't exist yet.
    //     // So we only allocate space for the pointers here. Each pointer is 32 bytes.
    //     // The total number of pointers made is equal to maxFacetInfoPointers
    //     // We will fill in the actual FacetInfo structs as we go.        
    //     FacetInfo[][] memory facetInfoOf = new FacetInfo[][](maxFacetInfoPointers);
        
    //     // count unique facets
    //     uint256 numFacets;             
        
    //     // Count unique facets and their selectors
    //     for (uint256 i; i < maxFacetInfoPointers; i++) {
    //         address facet = s.facetAndPosition[selectors[i]].facet;
                        
    //         // Look for existing facet
    //         uint256 facetIndex;
    //         for (; facetIndex < numFacets; facetIndex++) {                
    //             if (facetInfoOf[facetIndex][0].facet == facet) {
    //                 FacetInfo memory facetInfo = facetInfoOf[facetIndex][0];
    //                 if(facetInfo.count == facetInfo.selectors.length) {
    //                     // expand array
    //                     bytes4[] memory newSelectors = new bytes4[](facetInfo.count + 20);
    //                     for(uint256 j; j < facetInfo.count; j++) {
    //                         newSelectors[j] = facetInfo.selectors[j];
    //                     }
    //                     facetInfo.selectors = newSelectors;
    //                 }
    //                 facetInfo.selectors[facetInfo.count] = selectors[i];
    //                 facetInfo.count++;                    
    //                 break;
    //             }
    //         }
            
    //         // If facet not found, add it
    //         if (facetIndex == numFacets) {
    //             bytes4[] memory newSelectors = new bytes4[](20);
    //             newSelectors[0] = selectors[i];
    //             facetInfoOf[facetIndex] = new FacetInfo[](1);
    //             facetInfoOf[facetIndex][0] = FacetInfo({facet: facet, selectors: newSelectors, count: 1});                
    //             numFacets++;
    //         }
    //     }

    //     allFacets = new Facet[](numFacets);
        
    //     // Allocate return array with exact size
    //     // allFacets = new Facet[](numFacets);
    //     for (uint256 i; i < numFacets; i++) {
    //         FacetInfo memory facetInfo = facetInfoOf[i][0];
    //         allFacets[i].facet = facetInfo.facet;
    //         bytes4[] memory facetSelectors = facetInfo.selectors;
    //         uint256 facetSelectorCount = facetInfo.count;
    //         assembly {
    //             mstore(facetSelectors, facetSelectorCount)
    //         }
    //         allFacets[i].functionSelectors = facetSelectors;            
    //     }
    // }


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

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetSelectors The function selectors associated with a facet address.
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
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
