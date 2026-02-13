// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title Reference implementation for upgrade function for
 *        ERC-8153 Facet-Based Diamonds
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
 * Here is a example that shows the structure:
 *
 * FacetList
 *   facetCount          = 3
 *   headFacetNodeId   = selector1   // facetA
 *   tailFacetNodeId   = selector7   // facetC
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
 *
 * Checked/unchecked math note:
 * We use unchecked math with `facetList.selectorCount` because that variable does not affect the adding,
 * replacing, and removing of selectors and facets. It is used by some introspection functions. Checked math
 * is used with facetList.facetCount because that affects adding, replacing, and removing selectors and facets.
 * Of course these variables should never overflow/underflow anyway.
 *
 * Security:
 * This implementation relies on the assumption that the owner of the diamond that has added or replaced any
 * facet in the diamond has verified that each facet is not malicious, that each facet is immutable (not upgradeable),
 * and that the `exportSelectors()` function in each facet is pure (is marked as a pure function and does not access state.)
 */

interface IFacet {
    function exportSelectors() external pure returns (bytes memory);
}

bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8153.diamond");

struct FacetNode {
    address facet;
    bytes4 prevFacetNodeId;
    bytes4 nextFacetNodeId;
}

struct FacetList {
    bytes4 headFacetNodeId;
    bytes4 tailFacetNodeId;
    uint32 facetCount;
    uint32 selectorCount;
}

/**
 * @custom:storage-location erc8042:erc8109.diamond
 */
struct DiamondStorage {
    mapping(bytes4 functionSelector => FacetNode) facetNodes;
    FacetList facetList;
}

function getDiamondStorage() pure returns (DiamondStorage storage s) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Emitted when a facet is added to a diamond.
 * @dev The function selectors this facet handles can be retrieved by calling
 *      `IFacet(_facet).exportSelectors()`
 *
 * @param _facet The address of the facet that handles function calls to the diamond.
 */
event FacetAdded(address indexed _facet);

/**
 * @notice Emitted when an existing facet is replaced with a new facet.
 * @dev
 * - Selectors that are present in the new facet but not in the old facet are added to the diamond.
 * - Selectors that are present in both the new and old facet are updated to use the new facet.
 * - Selectors that are not present in the new facet but are present in the old facet are removed from
 *   the diamond.
 *
 * The function selectors handled by these facets can be retrieved by calling:
 * - `IFacet(_oldFacet).exportSelectors()`
 * - `IFacet(_newFacet).exportSelectors()`
 *
 * @param _oldFacet The address of the facet that previously handled function calls to the diamond.
 * @param _newFacet The address of the facet that now handles function calls to the diamond.
 */
event FacetReplaced(address indexed _oldFacet, address indexed _newFacet);

/**
 * @notice Emitted when a facet is removed from a diamond.
 * @dev The function selectors this facet handles can be retrieved by calling
 *      `IFacet(_facet).exportSelectors()`
 *
 * @param _facet The address of the facet that previously handled function calls to the diamond.
 */
event FacetRemoved(address indexed _facet);

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
error ExportSelectorsCallFailed(address _facet);
error IncorrectSelectorsEncoding(address _facet);

/**
 * @dev This error means that a function to replace exists in a
 *      facet other than the facet that was given to be replaced.
 */
error CannotReplaceFunctionFromNonReplacementFacet(bytes4 _selector);

function importSelectors(address _facet) view returns (bytes memory selectors) {
    (bool success, bytes memory data) = _facet.staticcall(abi.encodeWithSelector(IFacet.exportSelectors.selector));
    if (success == false) {
        revert ExportSelectorsCallFailed(_facet);
    }
    /*
     * Ensure the data is large enough.
     * Offset (32 bytes) + array length (32 bytes)
     */
    if (data.length < 64) {
        if (_facet.code.length == 0) {
            revert NoBytecodeAtAddress(_facet);
        } else {
            revert IncorrectSelectorsEncoding(_facet);
        }
    }

    // Validate ABI offset == 0x20 for a single dynamic return
    uint256 offset;
    assembly ("memory-safe") {
        offset := mload(add(data, 0x20))
    }
    if (offset != 0x20) {
        revert IncorrectSelectorsEncoding(_facet);
    }
    /*
     * ZERO-COPY DECODE
     * Instead of abi.decode(wrapper, (bytes)), which copies memory,
     * we use assembly to point 'selectors' to the bytes array inside 'data'.
     * The length of `data` is stored at 0 and an ABI offset is located at 0x20 (32).
     * We skip over those to point `selectors` to the length of the
     * bytes array.
     */
    assembly ("memory-safe") {
        selectors := add(data, 0x40)
    }
    uint256 selectorsLength = selectors.length;
    unchecked {
        if (selectorsLength > data.length - 64) {
            revert IncorrectSelectorsEncoding(_facet);
        }
    }
    if (selectorsLength < 4) {
        revert NoSelectorsForFacet(_facet);
    }
    /*
     * Function selectors are strictly 4 bytes. We ensure the length is a multiple of 4.
     */
    if (selectorsLength % 4 != 0) {
        revert IncorrectSelectorsEncoding(_facet);
    }
    return selectors;
}

function at(bytes memory selectors, uint256 index) pure returns (bytes4 selector) {
    assembly ("memory-safe") {
        /**
         * 1. Calculate Pointer
         * add(selectors, 32) - skips the length field of the bytes array
         * shl(2, index) is the same as index * 4 but cheaper
         * This line executes: ptr = selectorsLength + (4 * index)
         */
        let ptr := add(add(selectors, 32), shl(2, index))
        /**
         * 2. Load & Return
         * We load 32 bytes, but Solidity truncates to 4 bytes automatically
         * upon return of this function, so masking is unnecessary.
         */
        selector := mload(ptr)
    }
}

function addFacets(address[] calldata _facets) {
    DiamondStorage storage s = getDiamondStorage();
    uint256 facetLength = _facets.length;
    if (facetLength == 0) {
        return;
    }
    FacetList memory facetList = s.facetList;
    /*
     * Snapshot free memory pointer. We restore this at the end of every loop
     * to prevent memory expansion costs from repeated `packedSelectors` calls.
     */
    uint256 freeMemPtr;
    assembly ("memory-safe") {
        freeMemPtr := mload(0x40)
    }
    /* Algorithm Description:
     * The first facet is handled separately to initialize the linked list pointers in the FacetNodes.
     * This allows us to avoid additional conditional checks for linked list management in the main facet loop.
     *
     * For the first facet, we link the first selector to the previous facet or if this is the first facet in
     * the diamond then we assign the first selector to facetList.firstFacetNodeId.
     *
     * All the selectors (except the first one) in the first facet are then added to the diamond.
     *
     * In the first iteration of the main facet loop the the selectors for the next facet are retrieved.
     * This makes available the nextFacetNodeId value that is needed to store the first selector of the
     * first facet. So then the first selector is stored.
     *
     * Then the selectors which were already retrieved for the next facet are stored, except the first selector.
     * Then in the next iteration the selectors of the next facet are retrieved. This makes available the nextFacetNodeId
     * value that is needed to store the first selector of the previous facet. The first selector is then stored. The loop
     * continues.
     *
     * After the main facet loop ends, the first selector from the last facet is added to the diamond.
     */

    bytes4 prevFacetNodeId = facetList.tailFacetNodeId;
    address facet = _facets[0];
    bytes memory selectors = importSelectors(facet);
    /*
     * currentFacetNodeId is the head node of the current facet.
     * We cannot write it to storage yet because we don't know the `next` pointer.
     */
    bytes4 currentFacetNodeId = at(selectors, 0);
    if (facetList.facetCount == 0) {
        facetList.headFacetNodeId = currentFacetNodeId;
    } else {
        /*
         * Link the previous tail of the diamond to this new batch
         */
        s.facetNodes[prevFacetNodeId].nextFacetNodeId = currentFacetNodeId;
    }
    /*
     * Shift right by 2 is the same as dividing by 4, but cheaper.
     * We do this to get the number of selectors
     */
    uint256 selectorsLength = selectors.length >> 2;
    unchecked {
        facetList.selectorCount += uint32(selectorsLength);
    }
    /*
     * Add all selectors, except the first, to the diamond.
     */
    for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
        bytes4 selector = at(selectors, selectorIndex);
        if (s.facetNodes[selector].facet != address(0)) {
            revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
        }
        s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
    }
    /*
     * Reset memory for the main loop.
     */
    assembly ("memory-safe") {
        mstore(0x40, freeMemPtr)
    }
    /*
     * Main facet loop.
     * 1. Gets the next facet's selectors.
     * 2. Now that the nextFacetNodeId value for the previous facet is available, adds the previous
     *    facet's first selector to the diamond.
     * 3. Emits FacetAdded event for the previous facet.
     * 3. Updates facet values: facet = nextFacet, etc.
     * 4. Adds all the selectors (except the first) to the diamond.
     * 5. Repeat loop.
     */
    for (uint256 i = 1; i < facetLength; i++) {
        address nextFacet = _facets[i];
        selectors = importSelectors(nextFacet);
        /*
         * Check to see if the PENDING first selector (from previous iteration) already exists in the diamond.
         */
        if (s.facetNodes[currentFacetNodeId].facet != address(0)) {
            revert CannotAddFunctionToDiamondThatAlreadyExists(currentFacetNodeId);
        }
        /*
         * Identify the link to the next facet
         */
        bytes4 nextFacetNodeId = at(selectors, 0);
        /*
         * Store the previous facet's first selector.
         */
        s.facetNodes[currentFacetNodeId] = FacetNode(facet, prevFacetNodeId, nextFacetNodeId);
        emit FacetAdded(facet);
        /*
         * Move pointers forward.
         * These assignments switch us from processing the previous facet's first selector to
         * processing the next facet's selectors.
         * `currentFacetNodeId` becomes the new pending first selector.
         */
        facet = nextFacet;
        prevFacetNodeId = currentFacetNodeId;
        currentFacetNodeId = nextFacetNodeId;
        /*
         * Shift right by 2 is the same as dividing by 4, but cheaper.
         * We do this to get the number of selectors.
         */
        selectorsLength = selectors.length >> 2;
        /*
         * Add all the selectors of the facet to the diamond, except the first selector.
         */
        for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(selectors, selectorIndex);
            if (s.facetNodes[selector].facet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
        }
        unchecked {
            facetList.selectorCount += uint32(selectorsLength);
        }
        /*
         * Restore Free Memory Pointer to reuse memory from packedSelectors() calls.
         */
        assembly ("memory-safe") {
            mstore(0x40, freeMemPtr)
        }
    }
    /*
     * Validates and adds the first selector of the last facet to the diamond.
     */
    if (s.facetNodes[currentFacetNodeId].facet != address(0)) {
        revert CannotAddFunctionToDiamondThatAlreadyExists(currentFacetNodeId);
    }
    s.facetNodes[currentFacetNodeId] = FacetNode(facet, prevFacetNodeId, bytes4(0));
    emit FacetAdded(facet);
    facetList.facetCount += uint32(facetLength);

    facetList.tailFacetNodeId = currentFacetNodeId;
    s.facetList = facetList;
}

/**
 * @notice This struct is used to replace old facets with new facets.
 */
struct FacetReplacement {
    address oldFacet;
    address newFacet;
}

function replaceFacets(FacetReplacement[] calldata _replaceFacets) {
    DiamondStorage storage s = getDiamondStorage();
    FacetList memory facetList = s.facetList;
    /*
     * Snapshot free memory pointer. We restore this within the loop to prevent
     * memory expansion costs from repeated `packedSelectors` calls.
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
        bytes memory oldSelectors = importSelectors(oldFacet);
        bytes memory newSelectors = importSelectors(newFacet);
        /*
         * Shift right by 2 is the same as dividing by 4, but cheaper.
         * We do this to get the number of selectors
         */
        uint256 selectorsLength = newSelectors.length >> 2;
        bytes4 oldCurrentFacetNodeId = at(oldSelectors, 0);
        bytes4 newCurrentFacetNodeId = at(newSelectors, 0);

        /**
         * Validate old facet exists.
         */
        FacetNode memory oldFacetNode = s.facetNodes[oldCurrentFacetNodeId];
        if (oldFacetNode.facet != oldFacet) {
            revert FacetToReplaceDoesNotExist(oldFacet);
        }
        if (oldCurrentFacetNodeId != newCurrentFacetNodeId) {
            /**
             * Write first selector with linking info, then process remaining.
             */
            address existingFacet = s.facetNodes[newCurrentFacetNodeId].facet;
            if (existingFacet == address(0)) {
                unchecked {
                    facetList.selectorCount++;
                }
            } else if (existingFacet != oldFacet) {
                revert CannotReplaceFunctionFromNonReplacementFacet(newCurrentFacetNodeId);
            }
            s.facetNodes[newCurrentFacetNodeId] =
                FacetNode(newFacet, oldFacetNode.prevFacetNodeId, oldFacetNode.nextFacetNodeId);
            /**
             * Update linked list.
             */
            if (oldCurrentFacetNodeId == facetList.headFacetNodeId) {
                facetList.headFacetNodeId = newCurrentFacetNodeId;
            } else {
                s.facetNodes[oldFacetNode.prevFacetNodeId].nextFacetNodeId = newCurrentFacetNodeId;
            }
            if (oldCurrentFacetNodeId == facetList.tailFacetNodeId) {
                facetList.tailFacetNodeId = newCurrentFacetNodeId;
            } else {
                s.facetNodes[oldFacetNode.nextFacetNodeId].prevFacetNodeId = newCurrentFacetNodeId;
            }
        } else {
            /**
             * Same first selector, just replace in place.
             */
            s.facetNodes[newCurrentFacetNodeId] =
                FacetNode(newFacet, oldFacetNode.prevFacetNodeId, oldFacetNode.nextFacetNodeId);
            /*
             * If the selectors are same from both facets, then we can safely and very efficiently
             * replace the old facet address with the new facet address for all the selctors.
             */
            if (keccak256(oldSelectors) == keccak256(newSelectors)) {
                /**
                 * Replace remaining selectors.
                 */
                for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
                    bytes4 selector = at(newSelectors, selectorIndex);
                    s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
                }
                emit FacetReplaced(oldFacet, newFacet);
                /*
                 * Restore Free Memory Pointer to reuse memory.
                 */
                assembly ("memory-safe") {
                    mstore(0x40, freeMemPtr)
                }
                continue;
            }
        }

        /**
         * Add or replace new selectors.
         */
        for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(newSelectors, selectorIndex);
            address existingFacet = s.facetNodes[selector].facet;
            if (existingFacet == address(0)) {
                unchecked {
                    facetList.selectorCount++;
                }
            } else if (existingFacet != oldFacet) {
                revert CannotReplaceFunctionFromNonReplacementFacet(selector);
            }
            s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
        }
        /**
         * Remove old selectors that were not replaced.
         *
         * Shift right by 2 is the same as dividing by 4, but cheaper.
         * We do this to get the number of selectors.
         */
        selectorsLength = oldSelectors.length >> 2;
        for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(oldSelectors, selectorIndex);
            address existingFacet = s.facetNodes[selector].facet;
            if (existingFacet == oldFacet) {
                delete s.facetNodes[selector];
                unchecked {
                    facetList.selectorCount--;
                }
            }
        }
        emit FacetReplaced(oldFacet, newFacet);
        /*
         * Restore Free Memory Pointer to reuse memory.
         */
        assembly ("memory-safe") {
            mstore(0x40, freeMemPtr)
        }
    }
    s.facetList = facetList;
}

function removeFacets(address[] calldata _facets) {
    DiamondStorage storage s = getDiamondStorage();
    FacetList memory facetList = s.facetList;
    /*
     * Snapshot free memory pointer. We restore this at the end of every loop
     * to prevent memory expansion costs from repeated `packedSelectors` calls.
     */
    uint256 freeMemPtr;
    assembly ("memory-safe") {
        freeMemPtr := mload(0x40)
    }
    for (uint256 i = 0; i < _facets.length; i++) {
        address facet = _facets[i];
        bytes memory selectors = importSelectors(facet);
        bytes4 currentFacetNodeId = at(selectors, 0);
        FacetNode memory facetNode = s.facetNodes[currentFacetNodeId];
        /*
         * This verifies that the facet we are removing exists in the
         * diamond, so we can trust the rest of the selectors from `facet`.
         */
        if (facetNode.facet != facet) {
            revert CannotRemoveFacetThatDoesNotExist(facet);
        }
        /**
         * Remove the facet from the linked list.
         */
        if (currentFacetNodeId == facetList.headFacetNodeId) {
            facetList.headFacetNodeId = facetNode.nextFacetNodeId;
        } else {
            s.facetNodes[facetNode.prevFacetNodeId].nextFacetNodeId = facetNode.nextFacetNodeId;
        }
        if (currentFacetNodeId == facetList.tailFacetNodeId) {
            facetList.tailFacetNodeId = facetNode.prevFacetNodeId;
        } else {
            s.facetNodes[facetNode.nextFacetNodeId].prevFacetNodeId = facetNode.prevFacetNodeId;
        }
        /*
         * Shift right by 2 is the same as dividing by 4, but cheaper.
         * We do this to get the number of selectors
         */
        uint256 selectorsLength = selectors.length >> 2;
        /**
         * Remove facet selectors.
         * Because this facet is in the diamond and the `exportSelectors()` function is pure and
         * immutable from the facet and we trust that, we can safely remove the selectors without
         * checking that each selector belongs to the facet being removed. We know it does.
         */
        for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(selectors, selectorIndex);
            delete s.facetNodes[selector];
        }
        unchecked {
            facetList.selectorCount -= uint32(selectorsLength);
        }
        emit FacetRemoved(facet);
        /*
         * Restore Free Memory Pointer to reuse memory.
         */
        assembly ("memory-safe") {
            mstore(0x40, freeMemPtr)
        }
    }
    facetList.facetCount -= uint32(_facets.length);

    s.facetList = facetList;
}

/**
 * @notice Upgrade the diamond by adding, replacing, or removing facets.
 *
 * @dev
 * Facets are added first, then replaced, then removed.
 *
 * These events are emitted to record changes to facets:
 * - `FacetAdded(address indexed _facet)`
 * - `FacetReplaced(address indexed _oldFacet, address indexed _newFacet)`
 * - `FacetRemoved(address indexed _facet)`
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
) {
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
