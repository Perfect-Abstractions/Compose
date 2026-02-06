// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title Reference implementation for upgrade function for
 *        ERC-8109 Diamonds, Simplified
 *
 * @dev
 * Facets are stored as a doubly linked list and as a mapping of selectors to facet addresses.
 *
 * Facets are stored as a mapping of selectors to facet addresses for efficient delegatecall
 * routing to facets.
 *
 * Facets are stored as a doubly linked list for efficient iteration over all facets,
 * and for efficiently adding, replacing, and removing them.
 *
 * The `FacetList` struct contains information about the linked list of facets.
 *
 * Only the first FacetNode of each facet contains linked list pointers.
 *     * prevFacetNodeId - Is the selector of the first FacetNode of the previous
 *       facet.
 *     * nextFacetNodeId - Is the selector of the first FacetNode of the next
 *       facet.
 *
 * Here is a example that shows the structor:
 *
 * FacetList
 *   facetCount          = 3
 *   firstFacetNodeId  = selector1   // facetA
 *   lastFacetNodeId   = selector7   // facetC
 *
 * facetNodes mapping (selector => FacetNode)
 *
 *   selector   facet    prevFacetNodeId   nextFacetNodeId
 *   ----------------------------------------------------------------
 *   selector1  facetA   0x00000000          selector4   ← facetA LIST NODE
 *   selector2  facetA   0x00000000          0x00000000
 *   selector3  facetA   0x00000000          0x00000000
 *
 *   selector4  facetB   selector1           selector7   ← facetB LIST NODE
 *   selector5  facetB   0x00000000          0x00000000
 *   selector6  facetB   0x00000000          0x00000000
 *
 *   selector7  facetC   selector4           0x00000000  ← facetC LIST NODE
 *   selector8  facetC   0x00000000          0x00000000
 *   selector9  facetC   0x00000000          0x00000000
 *
 * Linked list order of facets:
 *
 *   facetA (selector1)
 *        ↓
 *   facetB (selector4)
 *        ↓
 *   facetC (selector7)
 *
 * Notes:
 * - Only the first selector of each facet participates in the linked list.
 * - The linked list connects facets, not individual selectors.
 * - Any values in "prevFacetNodeId" in non-first FacetNodes are not used.
 */
contract DiamondUpgradeFacet {
    /**
     * @notice Thrown when a non-owner attempts an action restricted to owner.
     */
    error OwnerUnauthorizedAccount();

    bytes32 constant OWNER_STORAGE_POSITION = keccak256("erc173.owner");

    /**
     * @custom:storage-location erc8042:erc8109.owner
     */
    struct OwnerStorage {
        address owner;
    }

    /**
     * @notice Returns a pointer to the owner storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The OwnerStorage struct in storage.
     */
    function getOwnerStorage() internal pure returns (OwnerStorage storage s) {
        bytes32 position = OWNER_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

    struct FacetNode {
        address facet;
        bytes4 prevFacetNodeId;
        bytes4 nextFacetNodeId;
    }

    struct FacetList {
        uint32 facetCount;
        uint32 selectorCount;
        bytes4 firstFacetNodeId;
        bytes4 lastFacetNodeId;
    }

    /**
     * @custom:storage-location erc8042:erc8109.diamond
     */
    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetNode) facetNodes;
        FacetList facetList;
    }

    function getDiamondStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Emitted when a function is added to a diamond.
     *
     * @param _selector The function selector being added.
     * @param _facet    The facet address that will handle calls to `_selector`.
     */
    event DiamondFunctionAdded(bytes4 indexed _selector, address indexed _facet);

    /**
     * @notice Emitted when changing the facet that will handle calls to a function.
     *
     * @param _selector The function selector being affected.
     * @param _oldFacet The facet address previously responsible for `_selector`.
     * @param _newFacet The facet address that will now handle calls to `_selector`.
     */
    event DiamondFunctionReplaced(bytes4 indexed _selector, address indexed _oldFacet, address indexed _newFacet);

    /**
     * @notice Emitted when a function is removed from a diamond.
     *
     * @param _selector The function selector being removed.
     * @param _oldFacet The facet address that previously handled `_selector`.
     */
    event DiamondFunctionRemoved(bytes4 indexed _selector, address indexed _oldFacet);

    /**
     * @notice Emitted when a diamond's constructor function or function from a
     *         facet makes a `delegatecall`.
     *
     * @param _delegate         The contract that was delegatecalled.
     * @param _delegateCalldata The function call, including function selector and
     *                          any arguments.
     */
    event DiamondDelegateCall(address indexed _delegate, bytes _delegateCalldata);

    /**
     * @notice Emitted to record information about a diamond.
     * @dev    This event records any arbitrary metadata.
     *         The format of `_tag` and `_data` are not specified by the
     *         standard.
     *
     * @param _tag   Arbitrary metadata, such as a release version.
     * @param _data  Arbitrary metadata.
     */
    event DiamondMetadata(bytes32 indexed _tag, bytes _data);

    /**
     * @notice The upgradeDiamond function below detects and reverts
     *         with the following errors.
     */
    error NoSelectorsForFacet(address _facet);
    error NoBytecodeAtAddress(address _contractAddress);
    error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
    error CannotRemoveFacetThatDoesNotExist(address _facet);
    error CannotReplaceFacetWithSameFacet(address _facet);
    error FacetToReplaceDoesNotExist(address _oldFacet);
    error DelegateCallReverted(address _delegate, bytes _delegateCalldata);
    error FunctionSelectorsCallFailed(address _facet);

    /**
     * @dev This error means that a function to replace exists in a
     *      facet other than the facet that was given to be replaced.
     */
    error CannotReplaceFunctionFromNonReplacementFacet(bytes4 _selector);

    function packedSelectors(address _facet) internal view returns (bytes memory selectors) {
        assembly ("memory-safe") {
            if iszero(extcodesize(_facet)) {
                /**
                 * error NoBytecodeAtAddress(address)
                 */
                mstore(0x00, 0xd94e3bbf00000000000000000000000000000000000000000000000000000000)
                mstore(0x04, _facet)
                revert(0x00, 0x24)
            }
            /**
             * 1. Initialize Pointer.
             * Load the Free Memory Pointer (0x40). This points to the start of currently
             * unallocated memory. We will use this space to build our 'selectors' array.
             */
            let ptr := mload(0x40)
            /**
             * 2. Prepare Calldata.
             * We reuse the 'ptr' memory temporarily to store the function selector for the call.
             * 0x3e62267c = bytes4(keccak256("packedSelectors()"))
             * Layout at 'ptr': [0x3e62267c... (padded to 32 bytes)]
             */
            mstore(ptr, 0x3e62267c00000000000000000000000000000000000000000000000000000000)
            /**
             * 3. Perform Staticcall.
             * out/outSize are 0 because we handle the output dynamically using returndatacopy.
             * The return data remains in the contract's "Return Data Buffer" for now.
             */
            let success :=
                staticcall(
                    gas(), // pass all available gas
                    _facet, // target address
                    ptr, // pointer to start of input
                    0x4, // input length (4 bytes for selector)
                    0, // out pointer, not used
                    0 // outSize, not used
                )
            /**
             * 4. Basic Safety Check.
             * We verify two things:
             * a) The call succeeded.
             * b) The return data is at least 68 bytes (Standard ABI Encoded Bytes).
             * 68 bytes = 32 (Offset) + 32 (Length) + 4 (Minimum 1 selector).
             */
            if or(iszero(success), lt(returndatasize(), 68)) {
                /**
                 * Handle Failure.
                 * If success is false, we revert with FunctionSelectorsCallFailed(address).
                 * If size < 68, we revert with NoSelectorsForFacet(address).
                 */
                if iszero(success) {
                    /**
                     * error FunctionSelectorsCallFailed(address)
                     */
                    mstore(0x00, 0x30319baa00000000000000000000000000000000000000000000000000000000)
                    mstore(0x04, _facet)
                    revert(0x00, 0x24)
                }
                // error NoSelectorsForFacet(address)
                mstore(0x00, 0x9c23886b00000000000000000000000000000000000000000000000000000000)
                mstore(0x04, _facet)
                revert(0x00, 0x24)
            }

            /**
             * 5. Initialize the Array & "Peek" Length.
             * We copy the Length word from the Return Data Buffer directly to 'ptr'.
             * - Source Offset: 0x20 (We skip the first 32 bytes, which is the ABI Offset).
             * - Length: 0x20 (We copy exactly 32 bytes).
             * Result: ptr now holds the declared length of the bytes array.
             */
            returndatacopy(ptr, 0x20, 0x20)
            let declaredLength := mload(ptr)
            /**
             * 6. Bounds Check.
             * Verify the Return Data Buffer actually contains the data declared by 'declaredLength'.
             * Formula: 32 (Offset) + 32 (Length Word) + declaredLength <= returndatasize()
             */
            if lt(returndatasize(), add(declaredLength, 0x40)) {
                revert(0, 0)
            }
            /**
             * 7. Domain Validation (4-Byte Alignment).
             * Function selectors are strictly 4 bytes. We ensure the length is a multiple of 4.
             * Logic: (x % 4 == 0) is equivalent to (x & 3 == 0).
             */
            if and(declaredLength, 3) {
                revert(0, 0)
            }
            /**
             * 8. Calculate Memory Size.
             * Solidity requires arrays to be padded to 32-byte boundaries in memory.
             * Formula: RoundUp32(x) = (x + 31) & ~31
             */
            let paddedLength := and(add(declaredLength, 0x1f), not(0x1f))

            /**
             * 9. Extraction & Auto-Padding.
             * We copy the data payload from the Return Data Buffer to memory.
             * - Dest:   ptr + 0x20 (After the Length word we set in Step 5).
             * - Source: 0x40 (Skip the 32-byte ABI Offset + 32-byte Length Word).
             * - Size:   paddedLength.
             *
             * MAGIC: If returndatasize is smaller than (64 + paddedLength), returndatacopy
             * automatically fills the remaining bytes with 0x00. This ensures the
             * memory is clean and perfectly padded without manual masking.
             */
            returndatacopy(add(ptr, 0x20), 0x40, paddedLength)
            /**
             * 10. Finalize Pointer.
             * Set the return variable 'selectors' to point to our new array in memory.
             */
            selectors := ptr
            /**
             * 11. Update Free Memory Pointer.
             * We advance the Free Memory Pointer to protect the data we just allocated.
             * New 0x40 = Start(ptr) + LengthWord(32) + Data(paddedLength).
             * No rounding is needed here because 'paddedLength' is already 32-byte aligned.
             */
            mstore(0x40, add(ptr, add(0x20, paddedLength)))
        }
    }

    function at(bytes memory selectors, uint256 index) internal pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            /**
             * 1. Calculate Pointer
             * add(selectors, 32) - skips the length field of the bytes array
             * shl(2, index) is the same as index * 4 but cheaper
             */
            let ptr := add(add(selectors, 32), shl(2, index))
            /**
             * 2. Load & Return
             * We load 32 bytes, but Solidity truncates to 4 bytes automatically
             * upon return assignment, so masking is unnecessary.
             */
            selector := mload(ptr)
        }
    }

    function addFacets(address[] calldata _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
        uint256 facetLength = _facets.length;
        if (facetLength == 0) {
            return;
        }
        FacetList memory facetList = s.facetList;
        /*
         * Store current Free Memory Pointer to restore later.
         * This is use to reuse memory in each loop iteration.
         */
        uint256 freeMemPtr;
        assembly ("memory-safe") {
            freeMemPtr := mload(0x40)
        }
        bytes4 prevFacetNodeId = facetList.lastFacetNodeId;
        address facet = _facets[0];
        bytes memory selectors = packedSelectors(facet);
        uint256 selectorsLength;
        unchecked {
            selectorsLength = selectors.length / 4;
            facetList.selectorCount += uint32(selectorsLength);
        }

        bytes4 currentFacetNodeId = at(selectors, 0);
        if (facetList.facetCount == 0) {
            facetList.firstFacetNodeId = currentFacetNodeId;
        } else {
            s.facetNodes[prevFacetNodeId].nextFacetNodeId = currentFacetNodeId;
        }
        emit DiamondFunctionAdded(currentFacetNodeId, facet);
        for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(selectors, selectorIndex);
            if (s.facetNodes[selector].facet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
            emit DiamondFunctionAdded(selector, facet);
        }
        /*
         * Restore Free Memory Pointer to reuse memory from packedSelectors() calls.
         */
        assembly ("memory-safe") {
            mstore(0x40, freeMemPtr)
        }
        for (uint256 i = 1; i < facetLength; i++) {
            if (s.facetNodes[currentFacetNodeId].facet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(currentFacetNodeId);
            }
            address nextFacet = _facets[i];
            selectors = packedSelectors(nextFacet);
            unchecked {
                selectorsLength = selectors.length / 4;
                facetList.selectorCount += uint32(selectorsLength);
            }
            bytes4 nextFacetNodeId = at(selectors, 0);
            s.facetNodes[currentFacetNodeId] = FacetNode(facet, prevFacetNodeId, nextFacetNodeId);
            facet = nextFacet;
            prevFacetNodeId = currentFacetNodeId;
            currentFacetNodeId = nextFacetNodeId;
            emit DiamondFunctionAdded(currentFacetNodeId, facet);
            for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(selectors, selectorIndex);
                if (s.facetNodes[selector].facet != address(0)) {
                    revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
                }
                s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
                emit DiamondFunctionAdded(selector, facet);
            }
            /*
             * Restore Free Memory Pointer to reuse memory from packedSelectors() calls.
             */
            assembly ("memory-safe") {
                mstore(0x40, freeMemPtr)
            }
        }
        if (s.facetNodes[currentFacetNodeId].facet != address(0)) {
            revert CannotAddFunctionToDiamondThatAlreadyExists(currentFacetNodeId);
        }
        s.facetNodes[currentFacetNodeId] = FacetNode(facet, prevFacetNodeId, bytes4(0));
        unchecked {
            facetList.facetCount += uint32(facetLength);
        }
        facetList.lastFacetNodeId = currentFacetNodeId;
        s.facetList = facetList;
    }

    /**
     * @notice This struct is used to replace old facets with new facets.
     */
    struct FacetReplacement {
        address oldFacet;
        address newFacet;
    }

    function replaceFacets(FacetReplacement[] calldata _replaceFacets) internal {
        DiamondStorage storage s = getDiamondStorage();
        FacetList memory facetList = s.facetList;
        /*
         * Store current Free Memory Pointer to restore later.
         * This is use to reuse memory in each loop iteration.
         */
        uint256 freeMemPtr;
        assembly ("memory-safe") {
            freeMemPtr := mload(0x40)
        }
        for (uint256 i; i < _replaceFacets.length; i++) {
            address oldFacet = _replaceFacets[i].oldFacet;
            address newFacet = _replaceFacets[i].newFacet;
            if (oldFacet == newFacet) {
                revert CannotReplaceFacetWithSameFacet(oldFacet);
            }
            bytes memory oldSelectors = packedSelectors(oldFacet);
            bytes memory newSelectors = packedSelectors(newFacet);
            uint256 selectorsLength;
            unchecked {
                selectorsLength = newSelectors.length / 4;
            }
            bytes4 oldCurrentFacetNodeId = at(oldSelectors, 0);
            bytes4 newCurrentFacetNodeId = at(newSelectors, 0);

            /**
             * Validate old facet exists.
             */
            FacetNode memory oldFacetNode = s.facetNodes[oldCurrentFacetNodeId];
            if (oldFacetNode.facet != oldFacet) {
                revert FacetToReplaceDoesNotExist(oldFacet);
            }
            /*
             * Restore Free Memory Pointer to reuse memory.
             */
            assembly ("memory-safe") {
                mstore(0x40, freeMemPtr)
            }
            if (oldCurrentFacetNodeId != newCurrentFacetNodeId) {
                /**
                 * Write first selector with linking info, then process remaining.
                 */
                address facet = s.facetNodes[newCurrentFacetNodeId].facet;
                if (facet == address(0)) {
                    emit DiamondFunctionAdded(newCurrentFacetNodeId, newFacet);
                    unchecked {
                        facetList.selectorCount++;
                    }
                } else if (facet == oldFacet) {
                    emit DiamondFunctionReplaced(newCurrentFacetNodeId, oldFacet, newFacet);
                } else {
                    revert CannotReplaceFunctionFromNonReplacementFacet(newCurrentFacetNodeId);
                }
                s.facetNodes[newCurrentFacetNodeId] =
                    FacetNode(newFacet, oldFacetNode.prevFacetNodeId, oldFacetNode.nextFacetNodeId);
                /**
                 * Update linked list.
                 */
                if (oldCurrentFacetNodeId == facetList.firstFacetNodeId) {
                    facetList.firstFacetNodeId = newCurrentFacetNodeId;
                } else {
                    s.facetNodes[oldFacetNode.prevFacetNodeId].nextFacetNodeId = newCurrentFacetNodeId;
                }
                if (oldCurrentFacetNodeId == facetList.lastFacetNodeId) {
                    facetList.lastFacetNodeId = newCurrentFacetNodeId;
                } else {
                    s.facetNodes[oldFacetNode.nextFacetNodeId].prevFacetNodeId = newCurrentFacetNodeId;
                }
            } else {
                /**
                 * Same first selector, just replace in place.
                 */
                s.facetNodes[newCurrentFacetNodeId] =
                    FacetNode(newFacet, oldFacetNode.prevFacetNodeId, oldFacetNode.nextFacetNodeId);
                emit DiamondFunctionReplaced(newCurrentFacetNodeId, oldFacet, newFacet);
                if (keccak256(oldSelectors) == keccak256(newSelectors)) {
                    /**
                     * Replace remaining selectors.
                     */
                    for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
                        bytes4 selector = at(newSelectors, selectorIndex);
                        s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
                        emit DiamondFunctionReplaced(selector, oldFacet, newFacet);
                    }
                    continue;
                }
            }

            /**
             * Add or replace new selectors.
             */
            for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(newSelectors, selectorIndex);
                address facet = s.facetNodes[selector].facet;
                if (facet == address(0)) {
                    emit DiamondFunctionAdded(selector, newFacet);
                    unchecked {
                        facetList.selectorCount++;
                    }
                } else if (facet == oldFacet) {
                    emit DiamondFunctionReplaced(selector, oldFacet, newFacet);
                } else {
                    revert CannotReplaceFunctionFromNonReplacementFacet(selector);
                }
                s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
            }
            /**
             * Remove old selectors that were not replaced.
             */
            unchecked {
                selectorsLength = oldSelectors.length / 4;
            }
            for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(oldSelectors, selectorIndex);
                address facet = s.facetNodes[selector].facet;
                if (facet == oldFacet) {
                    delete s.facetNodes[selector];
                    unchecked {
                        facetList.selectorCount--;
                    }
                    emit DiamondFunctionRemoved(selector, oldFacet);
                }
            }
        }
        s.facetList = facetList;
    }

    function removeFacets(address[] calldata _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
        FacetList memory facetList = s.facetList;
        /*
         * Store current Free Memory Pointer to restore later.
         * This is use to reuse memory in each loop iteration.
         */
        uint256 freeMemPtr;
        assembly ("memory-safe") {
            freeMemPtr := mload(0x40)
        }
        for (uint256 i = 0; i < _facets.length; i++) {
            address facet = _facets[i];
            bytes memory selectors = packedSelectors(facet);
            uint256 selectorsLength;
            unchecked {
                selectorsLength = selectors.length / 4;
                facetList.selectorCount -= uint32(selectorsLength);
            }
            bytes4 currentFacetNodeId = at(selectors, 0);
            FacetNode memory facetNode = s.facetNodes[currentFacetNodeId];
            if (facetNode.facet != facet) {
                revert CannotRemoveFacetThatDoesNotExist(facet);
            }
            /**
             * Remove the facet from the linked list.
             */
            if (currentFacetNodeId == facetList.firstFacetNodeId) {
                facetList.firstFacetNodeId = facetNode.nextFacetNodeId;
            } else {
                s.facetNodes[facetNode.prevFacetNodeId].nextFacetNodeId = facetNode.nextFacetNodeId;
            }
            if (currentFacetNodeId == facetList.lastFacetNodeId) {
                facetList.lastFacetNodeId = facetNode.prevFacetNodeId;
            } else {
                s.facetNodes[facetNode.nextFacetNodeId].prevFacetNodeId = facetNode.prevFacetNodeId;
            }
            /**
             * Remove facet selectors.
             */
            for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(selectors, selectorIndex);
                delete s.facetNodes[selector];
                emit DiamondFunctionRemoved(selector, facet);
            }
            /*
             * Restore Free Memory Pointer to reuse memory.
             */
            assembly ("memory-safe") {
                mstore(0x40, freeMemPtr)
            }
        }
        unchecked {
            facetList.facetCount -= uint32(_facets.length);
        }
        s.facetList = facetList;
    }

    /**
     * @notice Upgrade the diamond by adding, replacing, or removing facets.
     *
     * @dev
     * Facets are added first, then replaced, then removed.
     *
     * These events are emitted to record changes to functions:
     * - `DiamondFunctionAdded`
     * - `DiamondFunctionReplaced`
     * - `DiamondFunctionRemoved`
     *
     * If `_delegate` is non-zero, the diamond performs a `delegatecall` to
     * `_delegate` using `_delegateCalldata`. The `DiamondDelegateCall` event is
     *  emitted.
     *
     * The `delegatecall` is done to alter a diamond's state or to
     * initialize, modify, or remove state after an upgrade.
     *
     * However, if `_delegate` is zero, no `delegatecall` is made and no
     * `DiamondDelegateCall` event is emitted.
     *
     * If _tag is non-zero or if _metadata.length > 0 then the
     * `DiamondMetadata` event is emitted.
     *
     * @param _addFacets        Facets to add.
     * @param _replaceFacets    (oldFacet, newFacet) pairs, to replace old with new.
     * @param _removeFacets     Facets to remove.
     * @param _delegate         Optional contract to delegatecall (zero address to skip).
     * @param _delegateCalldata Optional calldata to execute on `_delegate`.
     * @param _tag              Optional arbitrary metadata, such as release version.
     * @param _metadata         Optional arbitrary data.
     */
    function upgradeDiamond(
        address[] calldata _addFacets,
        FacetReplacement[] calldata _replaceFacets,
        address[] calldata _removeFacets,
        address _delegate,
        bytes calldata _delegateCalldata,
        bytes32 _tag,
        bytes calldata _metadata
    ) external {
        if (getOwnerStorage().owner != msg.sender) {
            revert OwnerUnauthorizedAccount();
        }
        addFacets(_addFacets);
        replaceFacets(_replaceFacets);
        removeFacets(_removeFacets);
        if (_delegate != address(0)) {
            if (_delegate.code.length == 0) {
                revert NoBytecodeAtAddress(_delegate);
            }
            (bool success, bytes memory error) = _delegate.delegatecall(_delegateCalldata);
            if (!success) {
                if (error.length > 0) {
                    /*
                    * bubble up error
                    */
                    assembly ("memory-safe") {
                        revert(add(error, 0x20), mload(error))
                    }
                } else {
                    revert DelegateCallReverted(_delegate, _delegateCalldata);
                }
            }
            emit DiamondDelegateCall(_delegate, _delegateCalldata);
        }
        if (_tag != 0 || _metadata.length > 0) {
            emit DiamondMetadata(_tag, _metadata);
        }
    }

    function packedSelectors() external pure returns (bytes memory) {
        return bytes.concat(DiamondUpgradeFacet.upgradeDiamond.selector);
    }
}
