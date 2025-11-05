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

    function facets15() external view returns (Facet[] memory allFacets) {
        uint numFacets;

        DiamondStorage storage s = getStorage();
        uint256 selectorCount = s.selectors.length;
        uint[] memory selectorsFacetID = new uint[](selectorCount);
        uint[] memory uniqueFacets = new uint[](1); // [(160)address |(96) corresponding selectors count]
        uint facetIndex;

        for (uint256 i; i < selectorCount; i++) {
            address facet = s.facetAndPosition[s.selectors[i]].facet;
            // Look for existing facet
            for (facetIndex = 0; facetIndex < numFacets; facetIndex++) {
                if (uniqueFacets[facetIndex]>>96 == uint160(facet)) {
                    uniqueFacets[facetIndex]++;
                    break;
                }
            }            
            // If facet not found, add it
            if (facetIndex == numFacets) {
                numFacets++;
                assembly ("memory-safe"){
                    mstore(uniqueFacets, numFacets)
                }
                uniqueFacets[facetIndex] = (uint(uint160(facet))<<96) + 1;
            }
            selectorsFacetID[i] = facetIndex;
        }
        assembly{
            mstore(0x40,add(add(uniqueFacets,0x20),mul(mload(uniqueFacets),0x20)))
        }

        allFacets = new Facet[](numFacets);
    
        for (uint256 i; i < numFacets; i++) {
            allFacets[i].functionSelectors = new bytes4[](uint(uniqueFacets[i]) & 0xffffffffffffffffffffffff);
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

    
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    function facets14() external view returns (Facet[] memory allFacets) {
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
            uint256 mapIndex;
            for(; mapIndex < bucket.length; mapIndex++) {
                pointer = bucket[mapIndex];
                if(pointer == 0) {
                    bytes4[] memory selectorStorage = new bytes4[](20);
                    selectorStorage[0] = selector;
                    facetInfo = FacetInfo({facet: facet, selectors: selectorStorage, count: 1});                    
                    assembly ("memory-safe") {
                        pointer := facetInfo
                    }
                    bucket[mapIndex] = pointer;
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
            if(bucket.length == mapIndex) {
                // expand
                uint256[] memory newPointers = new uint256[](mapIndex + 3);
                for(uint256 k; k < mapIndex; k++) {
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
                bucket[mapIndex] = pointer;
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
        uint256[] memory bucket;

        // count unique facets
        uint256 numFacets;                     
        // Count unique facets and their selectors
        for (uint256 i; i < selectorsCount; i++) {            
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;                          
            // Look for existing facet            
            key =  uint256(uint160(facet)) & 0xff;
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

     /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetSelectors The function selectors associated with a facet address.
    function facetFunctionSelectors2(address _facet) external view returns (bytes4[] memory facetSelectors) {
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
                //assembly ("memory-safe") {
                assembly {
                    // Store selector in the next position in the facetSelectors array          
                    mstore(add(facetSelectors, mul(numSelectors, 0x20)), selector)
                }    
                
            }
        }        
        // assembly ("memory-safe") {
        assembly {
            // Set the total number of selectors in the array
            mstore(facetSelectors, numSelectors)
            // Properly allocate memory by setting memory pointer after facetSelectors array
            mstore(0x40, add(0x20, add(facetSelectors, mul(numSelectors, 0x20))))
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

    function facetAddresses3() external view returns (address[] memory allFacets) {
    assembly {
        // --- 0. Setup and Storage Pointers ---
        
        // Custom base storage position: keccak256("compose.diamond")
        let COMPOSE_DIAMOND_SLOT := 0x9dea51a0972159e0838d8a036f01982ec1d78b3b2a8e1570e8f17e011984b3ce
        
        // Diamond Storage Layout:
        let FACET_MAP_SLOT := COMPOSE_DIAMOND_SLOT          // facetAndPosition mapping slot

        // keccak256(COMPOSE_DIAMOND_SLOT + 1)
        let SELECTORS_BASE := 0x72c389824b9f57a6b0843a72db8f29826b9ecb297b4acd2b1188a7db453a6934
        
        // Memory start for the return array
        let FACETS_ARRAY_PTR := 0x80      
        
        // Start of array elements (FACETS_ARRAY_PTR + 32)
        let FACETS_ELEMENTS_PTR := 0xa0

        let selectorCount := sload(add(COMPOSE_DIAMOND_SLOT, 1)) // SLOAD the array length from SELECTORS_SLOT
        
        // --- 1. Initialization ---
        
        // Initialize the 256-bit collision map on the stack
        let collisionMap := 0
        let numFacets := 0  // Actual number of unique facets collected
        let i := 0          // Selector index
        
        // --- 2. Main Loop: Iterate Selectors and Uniquely Collect Facets ---
    
        // Store the mapping slot pointer once for facetAndPosition[selector].facet slot calculation
        mstore(0x20, FACET_MAP_SLOT)

        for { } lt(i, selectorCount) { i := add(i, 1) } {
            
            // --- 2a. Load Selector and Find Facet Address ---
                     
            // 1. Calculate selector's storage slot: i / 8 (8 selectors per 32 bytes)
            let selectorSlot := add(SELECTORS_BASE, div(i, 0x08))            
            
            // 2. SLOAD: Load the 32-byte word containing up to 8 selectors
            let packedWord := sload(selectorSlot)
            
            // 3. Calculate Bit Offset: (i % 8) * 4 bytes * 8 bits
            // This is the shift amount needed to move the selector to the rightmost position (LSB).
            let shiftAmount := mul(mod(i, 0x08), 0x20)
            
            // 4. Extract Selector: Shift right and mask (bytes4 is 4 bytes/32 bits) and shift to the left
            // @dev no need to mask bytes4 selector with 0xffffffff as shr and shl cleans remaining bits to 0
            let selector := shl(0xe0, shr(shiftAmount, packedWord))
            
            // Calculate storage slot for facetAndPosition[selector].facet
            mstore(0x00, selector)
            // Reuses constantly stored FACET_MAP_SLOT at 0x20
            let facetDataSlot := keccak256(0x00, 0x40) 
            
            // SLOAD 2: Load the facet address and clear out selector position
            let facetAddress := and(0xffffffffffffffffffffffffffffffffffffffff, sload(facetDataSlot))
            
            // --- 2b. O(1) Unique Check (Collision Map) ---
            
            let found := 0
            
            // Collision BitMask based on LSB of address
            let bitMask := shl(and(facetAddress, 0xff), 0x01)
            
            // Probabilistic O(1) Check: Check if the bit is set (collisionMap AND bitMask) != 0
            if iszero(iszero(and(collisionMap, bitMask))) {
                
                // Fallback: Linear O(N) check (only runs on hash collision)
                let facetIndex := 0
                for {} lt(facetIndex, numFacets) { facetIndex := add(facetIndex, 1) } {
                    let elementPtr := add(FACETS_ELEMENTS_PTR, mul(facetIndex, 0x20))
                    if eq(mload(elementPtr), facetAddress) {
                        found := 1
                        break
                    }
                }
            }
            
            // --- 2c. Conditional Append and Update Collision Map ---
            
            if iszero(found) {
                // Not found: Append the facet
                
                let newElementPtr := add(FACETS_ELEMENTS_PTR, mul(numFacets, 0x20))
                mstore(newElementPtr, facetAddress)
                
                // Update the collision map
                collisionMap := or(collisionMap, bitMask) 
                
                numFacets := add(numFacets, 1)
            }
        }
        
        // --- 3. Finalize Return Array ---

        // Memory start for the return data
        let RETURN_PTR := 0x60

        // Store offset of the array in the return data
        mstore(RETURN_PTR, 0x20)

        // Store the actual number of unique facets in the array's length slot
        mstore(FACETS_ARRAY_PTR, numFacets)
        
        // Return memory segment
        let returnSize := add(0x40, mul(numFacets, 0x20))
        return(RETURN_PTR, returnSize)
    }
}

    function facetAddresses2() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;
    
        // This is an array of pointers to FacetInfo structs which don't exist yet.                
        // We will fill in the actual FacetInfo structs as we go.
        allFacets = new address[](selectorsCount);
        
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
            uint256 bucketIndex;
            for(; bucketIndex < bucket.length; bucketIndex++) {
                address uniqueFacet = bucket[bucketIndex];
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

            if(bucketIndex == bucket.length) {                    
                // expand
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
