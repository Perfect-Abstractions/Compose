// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

//===================//
// General constants //
//===================//
uint256 constant SCRATCH_SPACE_POINTER_1 = 0x00;
uint256 constant SCRATCH_SPACE_POINTER_2 = 0x20;
uint256 constant FREE_MEMORY_POINTER = 0x40;

uint256 constant WORD_SIZE_1 = 0x20;
uint256 constant WORD_SIZE_2 = 0x40;

uint256 constant BYTE_SIZE_1_MASK = 0xff;
uint256 constant BYTE_SIZE_2_MASK = 0xffff;
uint256 constant BYTE_SIZE_4_MASK = 0xffffffff;

// Prefixed with `00` to emphasize that this is a bitmask, not an address.
uint256 constant ADDRESS_MASK = 0x00ffffffffffffffffffffffffffffffffffffffff;

// The functions in DiamondLoupeFacet MUST be added to a diamond.
// The EIP-2535 Diamond standard requires these functions.
contract DiamondLoupeFacet {
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

    /// @notice Struct to hold facet address and its function selectors
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }
    /// @dev Pre-computed result of `keccak256("compose.diamond")`
    bytes32 internal constant DIAMOND_STORAGE_POSITION =
        0x9dea51a0972159e0838d8a036f01982ec1d78b3b2a8e1570e8f17e011984b3ce;

    /// @dev Pre-computed result of `keccak256("compose.diamond") + 1`
    bytes32 internal constant SELECTORS_POSITION_POINTER =
        0x9dea51a0972159e0838d8a036f01982ec1d78b3b2a8e1570e8f17e011984b3cf;

    /// @dev Pre-computed result of `keccak256(keccak256("compose.diamond") + 1)`
    bytes32 internal constant STORAGE_POINTER_SELECTORS_ENTRIES =
        0x72c389824b9f57a6b0843a72db8f29826b9ecb297b4acd2b1188a7db453a6934;

    /// @dev Bitmask to get 4-byte function selector from packed data
    uint256 constant SELECTOR_MASK = BYTE_SIZE_4_MASK;

    /// @dev Bitmask to get 2-byte hash table index value from packed data
    uint256 constant TABLE_INDEX_MASK = BYTE_SIZE_2_MASK;

    /// @dev Bitmask to get 4-byte counter value from packed data
    uint256 constant COUNTER_MASK = BYTE_SIZE_4_MASK;

    /// @dev Bitmask to clear the 4-byte counter value from its hash table slot
    uint256 constant COUNT_FIELD_CLEARING_MASK = 0xffffffffffff00000000ffffffffffffffffffffffffffffffffffffffffffff;

    /// @notice Gets all facets and their selectors.
    /// @return allFacets Facet
    function facets() external view returns (Facet[] memory allFacets) {
        assembly {
            let selectorCount := sload(SELECTORS_POSITION_POINTER)

            if iszero(selectorCount) {
                // Fastest way to return an empty array, as the first slot is
                // the offset to the array length. Hence we offset 1 word, and
                // have an array length of 0.
                mstore(SCRATCH_SPACE_POINTER_1, WORD_SIZE_1)

                // It can't be assumed that scratch space is zeroed out, thus
                // it needs to be explicitly set to 0.
                mstore(SCRATCH_SPACE_POINTER_2, 0)

                return(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)
            }

            // Copy over constants to the stack for cheaper repeated access.
            let STACK_CONST_ADDR_MASK := ADDRESS_MASK
            let STACK_CONST_SELECTOR_OR_COUNT_MASK := BYTE_SIZE_4_MASK
            let STACK_CONST_BASE_SELECTOR_SLOT := STORAGE_POINTER_SELECTORS_ENTRIES

            // Place the `facetAndPosition` mapping's base storage position in
            // the scratch space to prepare for keccak256 hashing to access the
            // appropriate storage slots per function selector.
            mstore(SCRATCH_SPACE_POINTER_2, DIAMOND_STORAGE_POSITION)

            // Estimate facets to have 8 selectors. Calculate this without
            // using any branching for gas optimization.
            let div8 := shr(3, selectorCount)
            let isLessThanTwo := lt(div8, 2)
            let expectedUniqueFacets := add(mul(isLessThanTwo, 2), mul(iszero(isLessThanTwo), div8))

            // Target hash table capacity to be `2 * expectedUniqueFacets`,
            // which means a load factor of `<= 50%`. "Regular" applications
            // tend to target anywhere between a 50% to 70% load factor range,
            // but on-chain memory resizing can be costly, thus we aim lower.
            let targetHashTableSize := mul(2, expectedUniqueFacets)

            // Calculate the actual hash table size as the smallest power of 2
            // that's `>= targetHashTableSize`.
            //
            // To do this, we use a bit twiddling hack:
            // https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
            //
            // Cannot underflow, because `target >= 4`.
            // Also, the `>> 32` shift is likely overkill already.
            let hashTableSize := sub(targetHashTableSize, 1)
            hashTableSize := or(hashTableSize, shr(1, hashTableSize))
            hashTableSize := or(hashTableSize, shr(2, hashTableSize))
            hashTableSize := or(hashTableSize, shr(4, hashTableSize))
            hashTableSize := or(hashTableSize, shr(8, hashTableSize))
            hashTableSize := or(hashTableSize, shr(16, hashTableSize))
            hashTableSize := or(hashTableSize, shr(32, hashTableSize))
            hashTableSize := add(hashTableSize, 1)

            // Subtracting a power of 2 by 1 gives us the mask for that number
            // of bits, e.g. 2 ^ 8 = 256 --> 256 - 1 = 255 = 0xff
            //
            // This mask allows us to use a trick to use get the most out of
            // hashing the bits of a facet address.
            //
            // This property is combined with the hash table's size attribute,
            // as that allows for efficient locating of the correct slot in the
            // table.
            let hashTableMask := sub(hashTableSize, 1)

            // Hash table consists of `hashTableSize` slots of 32 bytes each.
            //
            // Layout of every slot:
            //   Bits   0 - 159: Facet address
            //   Bits 160 - 175: Index in the Facet[] array
            //                   Note: 16 bits, so capped at 65,535 addresses,
            //                         but that should be enough.
            //   Bits 176 - 207: Count of selectors, or write index. These bits
            //                   are re-used for two different purposes. This
            //                   could have been split out into the unused bit,
            //                   but the functionalities are similar enough, and
            //                   no gas penalty is incurred in this way.
            //   Bits 208 - 255: Unused bits
            let table := mload(FREE_MEMORY_POINTER)
            let tableEnd := add(table, shl(5, hashTableSize))
            mstore(FREE_MEMORY_POINTER, tableEnd)

            let unique := 0

            // The following scoped snippet fetches the facet address of each
            // function selector and count how many selectors each facet has.
            //
            // At this point, we do not retain the function selector in memory.
            // Memory expansion costs scale quadratically, thus we choose to
            // use memory in a "just in time"-like manner to support more
            // facets and selectors.
            //
            // Instead, we make use of the EVMs hot/cold storage SLOAD system,
            // where subsequent storage reads in the same transaction or call
            // are considerably cheaper. See:
            // https://www.evm.codes/about#access_list
            //
            // For memory expansion costs, see:
            // https://www.evm.codes/about#memoryexpansion
            {
                // Count how many fully packed selector slots to process, and
                // how many "remaining" selectors there are in the last slot
                // that's not full.
                //
                // For each full selector slot, we perform an almost equivalent
                // operation 8 times, as that is how many selectors fit into a
                // single storage slot.
                //
                // These operations do not make use of a helper function as
                // that would incur extra gas cost.
                //
                // The remaining selectors are processed in a similar manner,
                // albeit outside the loop, and up to 7 times (just shy of a
                // full storage slot).
                //
                // shr(3, x) = div(x, 8)
                let selectorSlots := shr(3, selectorCount)
                let remainingSelectors := mod(selectorCount, 8)

                for { let slotIndex := 0 } lt(slotIndex, selectorSlots) { slotIndex := add(slotIndex, 1) } {
                    let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, slotIndex))

                    {
                        // We unpack the first selector:
                        // shl(224, and(packedSelectors, 0xffffffff))
                        //
                        // Similar steps are repeated below 7 times to unpack
                        // the other selectors.
                        //
                        // No need to store the unpacked selector on the stack
                        // as we're only counting them at this stage.
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(packedSelectors, SELECTOR_MASK)))

                        // Hashes the stored selector and mapping position to
                        // get the storage slot for the facet address.
                        //
                        // That same slot also contains a `uint16 position`, as
                        // the two pieces of data are tightly packed. To only
                        // get the address, a bitmask is used.
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)

                        // Hash the facet address to get a deterministic
                        // starting point in the hash table.
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        // Loop to find a valid slot in the hash table.
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)

                            // No existing facet was found, thus this facet is
                            // unique. We store it with a selector count of 1.
                            if iszero(tableSlot) {
                                // Combine facet address with a selector count
                                // of 1, and store that in the hash table.
                                //
                                // The optimizer converts shl(176, 1) into a
                                // constant, so no need to do that manually.
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }

                            // Found existing facet in the table, so increment
                            // its selector counter.
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                // Consists of the following steps:
                                // 1. Read the current selector count
                                //    and(shr(176, tableSlot), 0xffffffff)
                                //
                                // 2. Increment count by 1
                                //    add(<step-1>, 1)
                                //
                                // 3. Remove `count` component from memory slot
                                //    and(tableSlot, COUNT_FIELD_CLEARING_MASK)
                                //
                                // 4. Prepare new `count` component
                                //    shl(176, <step-2>)
                                //
                                // 5. Combine new component with existing slot data
                                //    or(<step-3>, <step-4>)
                                //
                                // 6. Store updated component in table
                                //    mstore(tablePtr, <step-5>)
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }

                            // Facet selector not found. It may be in the next
                            // slot of the hash table, so we continue with
                            // linear probing.
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(32, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(64, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(96, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(128, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(160, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(192, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(224, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                }

                // Same as in the above loop, but handled outside the loop as
                // many times as needed.
                if remainingSelectors {
                    let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, selectorSlots))

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(packedSelectors, SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 1) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(32, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 2) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(64, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 3) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(96, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 4) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(128, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 5) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(160, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 6) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(192, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, or(facetAddress, shl(176, 1)))
                                unique := add(unique, 1)
                                break
                            }
                            if eq(and(tableSlot, STACK_CONST_ADDR_MASK), facetAddress) {
                                mstore(
                                    tablePtr,
                                    or(and(tableSlot, COUNT_FIELD_CLEARING_MASK), shl(176, add(shr(176, tableSlot), 1)))
                                )
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                }
            }

            // The return data is of type `Facet[]`, which means the following:
            //  1. The array itself is a dynamic type
            //  2. Each `Facet` struct contains a dynamic type, i.e. the array
            //     of `functionSelectors`
            //
            // Thus we are dealing with a doubly dynamic dynamic type, and need
            // to account for the offsets in the returned data.
            //
            // It is recommended to read the Contract ABI Specification page:
            // https://docs.soliditylang.org/en/v0.8.30/abi-spec.html
            //
            // Most notably these 2 sections:
            // 1. Formal Specification of the Encoding
            // 2. Use of Dynamic Types
            //
            // For convenience, here's a breakdown of the memory layout for a
            // Facet[] array for the following scenario:
            //  1. Facet A (0xAAAA) - Selectors: 0x1A, 0x2A, 0x3A
            //  2. Facet B (0xBBBB) - Selectors: 0x4B, 0x5B
            //
            // Shortened `returnPtr` to `R`.
            //
            // Pointer   | Content | Explaantion
            // ----------+---------+----------------------------------------------
            // R         | 0x20    | Offset to the start of Facet[] data
            // ----------+---------+----------------------------------------------
            // R + 0x20  | 0x02    | Length of Facet[]
            // R + 0x40  | 0x40    | Offset from here (R + 0x20) to Facet A data
            // R + 0x60  | 0xA0    | Offset from here (R + 0x20) to Facet B data
            // ----------+---------+----------------------------------------------
            // R + 0x80  | 0xAAAA  | Address of facet A
            // R + 0xA0  | 0x20    | Offset to Facet A's functionSelectors[] data
            // ----------+---------+----------------------------------------------
            // R + 0xC0  | 0x03    | Length of Facet A's functionSelectors[]
            // R + 0xE0  | 0x1A    | Selector 1A
            // R + 0x100 | 0x2A    | Selector 2A
            // R + 0x120 | 0x3A    | Selector 3A
            // ----------+---------+----------------------------------------------
            // R + 0x140 | 0xBBBB  | Address of facet B
            // R + 0x160 | 0x20    | Offset to Facet B's functionSelectors[] data
            // ----------+---------+----------------------------------------------
            // R + 0x180 | 2       | Length of Facet B's functionSelectors[]
            // R + 0x1A0 | 0x4B    | Selector 4B
            // R + 0x1C0 | 0x5B    | Selector 5B
            // ----------+---------+----------------------------------------------
            let returnPtr := mload(FREE_MEMORY_POINTER)
            mstore(returnPtr, WORD_SIZE_1)

            let arrayLengthPtr := add(returnPtr, WORD_SIZE_1)
            mstore(arrayLengthPtr, unique)

            let facetOffsetsPtr := add(arrayLengthPtr, WORD_SIZE_1)

            // Moving pointer to track the next free memory to write data to.
            let dataWriteCursor := add(facetOffsetsPtr, shl(5, unique))

            // Scan the entire hash table for facet addresses, and reserves the
            // necessary amount of memory to later inject the function
            // selectors into while already writing the facet addresses and
            // offsets into the correct positions.
            {
                let arrayIndex := 0

                for { let tableIndex := 0 } lt(tableIndex, hashTableSize) { tableIndex := add(tableIndex, 1) } {
                    let tableSlotPtr := add(table, shl(5, tableIndex))
                    let tableSlot := mload(tableSlotPtr)

                    if iszero(tableSlot) {
                        continue
                    }

                    let facetAddress := and(tableSlot, ADDRESS_MASK)
                    let facetSelectorCount := shr(176, tableSlot)

                    // Track offset from the write cursor position back to the
                    // start of the offsets array.
                    mstore(add(facetOffsetsPtr, shl(5, arrayIndex)), sub(dataWriteCursor, facetOffsetsPtr))

                    let currentFacetPtr := dataWriteCursor
                    mstore(currentFacetPtr, facetAddress)

                    // The `functionSelectors` array body (i.e., its length and
                    // data) will start after the struct head, which is 0x40 bytes.
                    let selectorsBodyPtr := add(currentFacetPtr, WORD_SIZE_2)

                    mstore(add(currentFacetPtr, WORD_SIZE_1), sub(selectorsBodyPtr, currentFacetPtr))
                    mstore(selectorsBodyPtr, facetSelectorCount)

                    // Move the cursor past the memory we reserved for this
                    // facet's entire data block.
                    dataWriteCursor := add(selectorsBodyPtr, add(WORD_SIZE_1, shl(5, facetSelectorCount)))

                    // Store the `arrayIndex` in the `idx1` field.
                    //
                    // Note that we are storing `index + 1`, so we can use `0`
                    // as a null value.
                    mstore(tableSlotPtr, or(facetAddress, shl(160, add(arrayIndex, 1))))

                    arrayIndex := add(arrayIndex, 1)
                    if eq(arrayIndex, unique) {
                        break
                    }
                }
            }
            mstore(FREE_MEMORY_POINTER, dataWriteCursor)

            // Do a second storage read pass to fetch the function selectors.
            // This is relatively cheap, because the storage slots are already
            // considered warm.
            {
                let selectorSlots := shr(3, selectorCount)
                let remainingSelectors := mod(selectorCount, 8)

                for { let slotIndex := 0 } lt(slotIndex, selectorSlots) { slotIndex := add(slotIndex, 1) } {
                    let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, slotIndex))

                    // This snippet processes one function selector. It finds
                    // where the selector belongs in the final return data and
                    // writes it there.
                    //
                    // The snippet is repeated 8 times in this loop for gas
                    // optimization purposes. Similarly, it happens at most 7
                    // times outside of this loop.
                    {
                        let selector := shl(224, and(packedSelectors, SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                // Extract the 1-based index we stored when
                                // scanning the hash table.
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    // Calculate the absolute memory pointer to
                                    // the start of this Facet's struct data.
                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    // 1. Fetch number of function selectors
                                    //    that were already written.
                                    //
                                    // 2. Write selector into correct space.
                                    //
                                    // 3. Increment the counter, and update it
                                    //    in the hash table.
                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            // Continue searching via linear probe.
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(32, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(64, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(96, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(128, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(160, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(192, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        let selector := shl(224, and(shr(224, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                }

                if remainingSelectors {
                    let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, selectorSlots))

                    {
                        let selector := shl(224, and(packedSelectors, SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    if gt(remainingSelectors, 1) {
                        let selector := shl(224, and(shr(32, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    if gt(remainingSelectors, 2) {
                        let selector := shl(224, and(shr(64, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    if gt(remainingSelectors, 3) {
                        let selector := shl(224, and(shr(96, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    if gt(remainingSelectors, 4) {
                        let selector := shl(224, and(shr(128, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    if gt(remainingSelectors, 5) {
                        let selector := shl(224, and(shr(160, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    if gt(remainingSelectors, 6) {
                        let selector := shl(224, and(shr(192, packedSelectors), SELECTOR_MASK))
                        mstore(SCRATCH_SPACE_POINTER_1, selector)
                        let facetAddress := and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), ADDRESS_MASK)

                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))

                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if eq(and(tableSlot, ADDRESS_MASK), facetAddress) {
                                let arrayIndex1 := and(shr(160, tableSlot), TABLE_INDEX_MASK)

                                if arrayIndex1 {
                                    let arrayIndex := sub(arrayIndex1, 1)

                                    let facetStructOffset := mload(add(facetOffsetsPtr, shl(5, arrayIndex)))
                                    let pointerToFacetStruct := add(facetOffsetsPtr, facetStructOffset)

                                    let selectorsWrittenCount := shr(176, tableSlot)
                                    let selectorWritePtr :=
                                        add(add(pointerToFacetStruct, 0x60), shl(5, selectorsWrittenCount))
                                    mstore(selectorWritePtr, selector)
                                    mstore(
                                        tablePtr,
                                        or(
                                            and(tableSlot, COUNT_FIELD_CLEARING_MASK),
                                            shl(176, add(selectorsWrittenCount, 1))
                                        )
                                    )
                                }
                                break
                            }

                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                }
            }

            return(returnPtr, sub(mload(FREE_MEMORY_POINTER), returnPtr))
        }
    }

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetSelectors The function selectors associated with a facet address.
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        assembly {
            let selectorCount := sload(SELECTORS_POSITION_POINTER)

            if iszero(selectorCount) {
                // Fastest way to return an empty array, as the first slot is
                // the offset to the array length. Hence we offset 1 word, and
                // have an array length of 0.
                mstore(SCRATCH_SPACE_POINTER_1, WORD_SIZE_1)

                // It can't be assumed that scratch space is zeroed out, thus
                // it needs to be explicitly set to 0.
                mstore(SCRATCH_SPACE_POINTER_2, 0)

                return(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)
            }

            // Copy over constants to the stack for cheaper repeated access.
            let STACK_CONST_ADDR_MASK := ADDRESS_MASK
            let STACK_CONST_BASE_SELECTOR_SLOT := STORAGE_POINTER_SELECTORS_ENTRIES
            let STACK_CONST_SELECTOR_MASK := SELECTOR_MASK

            // Place the `facetAndPosition` mapping's base storage position in
            // the scratch space to prepare for keccak256 hashing to access the
            // appropriate storage slots per function selector.
            mstore(SCRATCH_SPACE_POINTER_2, DIAMOND_STORAGE_POSITION)

            let returnPtr := mload(FREE_MEMORY_POINTER)

            // Moving pointer to track the next free memory to write data to.
            let dataWriteCursor := add(returnPtr, WORD_SIZE_2)

            // Count how many fully packed selector slots to process, and how 
            // many "remaining" selectors there are in the last slot that's not
            // full.
            //
            // For each full selector slot, we perform an almost equivalent
            // operation 8 times, as that is how many selectors fit into a
            // single storage slot.
            //
            // These operations do not make use of a helper function as
            // that would incur extra gas cost.
            //
            // The remaining selectors are processed in a similar manner,
            // albeit outside the loop, and up to 7 times (just shy of a full
            // storage slot).
            //
            // shr(3, x) = div(x, 8)
            let selectorSlots := shr(3, selectorCount)
            let remainingSelectors := mod(selectorCount, 8)

            for { let slotIndex := 0 } lt(slotIndex, selectorSlots) {
                slotIndex := add(slotIndex, 1)
            } {
                let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, slotIndex))

                // This snippet processes one function selector. It checks if
                // the selector belongs to the correct facet, and if so, writes 
                // it to the correct memory position.
                //
                // The snippet is repeated 8 times in this loop for gas
                // optimization purposes. Similarly, it happens at most 7 times
                // outside of this loop.
                //
                // The only changing variable is the selector. The rest of the
                // snippet is exactly the same for all those 15 iterations, but
                // unrolling them like this saves the gas cost from the JUMP
                // related opcodes.
                {
                    let selector := shl(224, and(packedSelectors, STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, and(shr(32, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, and(shr(64, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, and(shr(96, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, and(shr(128, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, and(shr(160, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, and(shr(192, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                {
                    let selector := shl(224, shr(224, packedSelectors))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
            }

            if remainingSelectors {
                let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, selectorSlots))

                {
                    let selector := shl(224, and(packedSelectors, STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                if gt(remainingSelectors, 1) {
                    let selector := shl(224, and(shr(32, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                if gt(remainingSelectors, 2) {
                    let selector := shl(224, and(shr(64, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                if gt(remainingSelectors, 3) {
                    let selector := shl(224, and(shr(96, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                if gt(remainingSelectors, 4) {
                    let selector := shl(224, and(shr(128, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                if gt(remainingSelectors, 5) {
                    let selector := shl(224, and(shr(160, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
                if gt(remainingSelectors, 6) {
                    let selector := shl(224, and(shr(192, packedSelectors), STACK_CONST_SELECTOR_MASK))
                    mstore(SCRATCH_SPACE_POINTER_1, selector)
                    if eq(and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK), _facet) {
                        mstore(dataWriteCursor, selector)
                        dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                    }
                }
            }

            // Set free memory pointer to the correct address. The last word
            // that was added to `dataWriteCursor` is still unused.
            mstore(FREE_MEMORY_POINTER, dataWriteCursor)

            // Set return data offset to array start as per ABI.
            mstore(returnPtr, WORD_SIZE_1)


            // The first slot after `returnPtr` marks the start of the return 
            // data.
            //
            // The return data is a dynamic array. The first slot is its length
            // and we get the length by dividing the total number of bytes used
            // by the array elements by the size of a memory slot.
            //
            // This does rely on the elements being placed "normally", and not
            // in a tightly packed encoding.
            let selectorBytes := sub(dataWriteCursor, add(returnPtr, WORD_SIZE_2))
            mstore(add(returnPtr, WORD_SIZE_1), div(selectorBytes, WORD_SIZE_1))

            return(returnPtr, add(WORD_SIZE_2, selectorBytes))
        }
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return allFacets The facet addresses.
    function facetAddresses() external view returns (address[] memory allFacets) {
        assembly {
            let selectorCount := sload(SELECTORS_POSITION_POINTER)

            if iszero(selectorCount) {
                // Fastest way to return an empty array, as the first slot is
                // the offset to the array length. Hence we offset 1 word, and
                // have an array length of 0.
                mstore(SCRATCH_SPACE_POINTER_1, WORD_SIZE_1)

                // It can't be assumed that scratch space is zeroed out, thus
                // it needs to be explicitly set to 0.
                mstore(SCRATCH_SPACE_POINTER_2, 0)

                return(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)
            }

            // Hot constants
            let STACK_CONST_ADDR_MASK := ADDRESS_MASK
            let STACK_CONST_BASE_SELECTOR_SLOT := STORAGE_POINTER_SELECTORS_ENTRIES

            mstore(SCRATCH_SPACE_POINTER_2, DIAMOND_STORAGE_POSITION)

            // Estimate facets to have 8 selectors. Calculate this without
            // using any branching for gas optimization.
            let div8 := shr(3, selectorCount)
            let isLessThanTwo := lt(div8, 2)
            let expectedUniqueFacets := add(mul(isLessThanTwo, 2), mul(iszero(isLessThanTwo), div8))

            // Target hash table capacity to be `2 * expectedUniqueFacets`,
            // which means a load factor of `<= 50%`. "Regular" applications
            // tend to target anywhere between a 50% to 70% load factor range,
            // but on-chain memory resizing can be costly, thus we aim lower.
            let targetHashTableSize := mul(2, expectedUniqueFacets)

            // Calculate the actual hash table size as the smallest power of 2
            // that's `>= targetHashTableSize`.
            //
            // To do this, we use a bit twiddling hack:
            // https://graphics.stanford.edu/~seander/bithacks.html#RoundUpPowerOf2
            //
            // Cannot underflow, because `target >= 4`.
            // Also, the `>> 32` shift is likely overkill already.
            let hashTableSize := sub(targetHashTableSize, 1)
            hashTableSize := or(hashTableSize, shr(1, hashTableSize))
            hashTableSize := or(hashTableSize, shr(2, hashTableSize))
            hashTableSize := or(hashTableSize, shr(4, hashTableSize))
            hashTableSize := or(hashTableSize, shr(8, hashTableSize))
            hashTableSize := or(hashTableSize, shr(16, hashTableSize))
            hashTableSize := or(hashTableSize, shr(32, hashTableSize))
            hashTableSize := add(hashTableSize, 1)

            // Subtracting a power of 2 by 1 gives us the mask for that number
            // of bits, e.g. 2 ^ 8 = 256 --> 256 - 1 = 255 = 0xff
            //
            // This mask allows us to use a trick to use get the most out of
            // hashing the bits of a facet address.
            //
            // This property is combined with the hash table's size attribute,
            // as that allows for efficient locating of the correct slot in the
            // table.
            let hashTableMask := sub(hashTableSize, 1)

            // Hash table consists of `hashTableSize` slots of 32 bytes each.
            //
            // Layout of every slot:
            //   Bits   0 - 159: Facet address
            //   Bits 160 - 255: Unused bits
            let table := mload(FREE_MEMORY_POINTER)
            let tableEnd := add(table, shl(5, hashTableSize))
            mstore(FREE_MEMORY_POINTER, tableEnd)

            let unique := 0
            {
                let selectorSlots := div(selectorCount, 8)
                let remainingSelectors := mod(selectorCount, 8)

                for { let slotIndex := 0 } lt(slotIndex, selectorSlots) { slotIndex := add(slotIndex, 1) } {
                    let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, slotIndex))

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(packedSelectors, SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(32, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(64, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(96, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(128, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(160, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(192, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(224, packedSelectors), SELECTOR_MASK)))

                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                }

                if remainingSelectors {
                    let packedSelectors := sload(add(STACK_CONST_BASE_SELECTOR_SLOT, selectorSlots))

                    {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(packedSelectors, SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 1) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(32, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 2) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(64, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 3) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(96, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 4) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(128, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 5) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(160, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                    if gt(remainingSelectors, 6) {
                        mstore(SCRATCH_SPACE_POINTER_1, shl(224, and(shr(192, packedSelectors), SELECTOR_MASK)))
                        let facetAddress :=
                            and(sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)), STACK_CONST_ADDR_MASK)
                        let tableIndex := and(facetAddress, hashTableMask)
                        let tablePtr := add(table, shl(5, tableIndex))
                        for {} 1 {} {
                            let tableSlot := mload(tablePtr)
                            if iszero(tableSlot) {
                                mstore(tablePtr, facetAddress)
                                unique := add(unique, 1)
                                break
                            }
                            if eq(tableSlot, facetAddress) {
                                break
                            }
                            tableIndex := and(add(tableIndex, 1), hashTableMask)
                            tablePtr := add(table, shl(5, tableIndex))
                        }
                    }
                }
            }

            let returnPtr := mload(FREE_MEMORY_POINTER)
            mstore(returnPtr, WORD_SIZE_1)

            let arrayLengthPtr := add(returnPtr, WORD_SIZE_1)
            mstore(arrayLengthPtr, unique)

            let dataWriteCursor := add(arrayLengthPtr, WORD_SIZE_1)
            let arrayIndex := 0

            // Scan the entire hash table for facet addresses and write them 
            // into the correct memory position.
            for { let tableIndex := 0 } lt(tableIndex, hashTableSize) { tableIndex := add(tableIndex, 1) } {
                let tableSlot := mload(add(table, shl(5, tableIndex)))
                if iszero(tableSlot) {
                    continue
                }

                mstore(dataWriteCursor, tableSlot)

                dataWriteCursor := add(dataWriteCursor, WORD_SIZE_1)
                arrayIndex := add(arrayIndex, 1)

                // All facet addresses found. Can stop scanning.
                if eq(arrayIndex, unique) {
                    break
                }
            }

            return(returnPtr, sub(dataWriteCursor, returnPtr))
        }
    }

    /// @notice Gets the facet address that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facet The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        assembly {
            // Place `_functionSelector` and `facetAndPosition` mapping's base 
            // storage position in sequential scratch space memory slots to 
            // prepare for keccak256 hashing to access the storage slot of the
            // given function selector.
            mstore(SCRATCH_SPACE_POINTER_1, _functionSelector)
            mstore(SCRATCH_SPACE_POINTER_2, DIAMOND_STORAGE_POSITION)

            // We explicitly don't mask the data, because the ABI specification
            // forces clients to ignore the other bits outside the 160 bits of
            // the address return type.
            mstore(SCRATCH_SPACE_POINTER_1, sload(keccak256(SCRATCH_SPACE_POINTER_1, WORD_SIZE_2)))

            return(SCRATCH_SPACE_POINTER_1, WORD_SIZE_1)
        }
    }
}
