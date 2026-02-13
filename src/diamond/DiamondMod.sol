// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
* @title Diamond Module
* @notice Internal functions and storage for diamond proxy functionality.
* @dev Follows EIP-8153 Facet-Based Diamonds
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
 * @param _facet The address of the facet that previouly handled function calls to the diamond.
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
error FunctionSelectorsCallFailed(address _facet);
error IncorrectSelectorsEncoding(address _facet);

function importSelectors(address _facet) view returns (bytes memory selectors) {
    (bool success, bytes memory data) = _facet.staticcall(abi.encodeWithSelector(IFacet.exportSelectors.selector));
    if (success == false) {
        revert FunctionSelectorsCallFailed(_facet);
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

function addFacets(address[] memory _facets) {
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

error FunctionNotFound(bytes4 _selector);

/**
 * Find facet for function that is called and execute the
 * function if a facet is found and return any value.
 */
function diamondFallback() {
    DiamondStorage storage s = getDiamondStorage();
    /**
     * get facet from function selector
     */
    address facet = s.facetNodes[msg.sig].facet;
    if (facet == address(0)) {
        revert FunctionNotFound(msg.sig);
    }
    /*
     * Execute external function from facet using delegatecall and return any value.
     */
    assembly {
        /*
         * copy function selector and any arguments
         */
        calldatacopy(0, 0, calldatasize())
        /*
         * execute function call using the facet
         */
        let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
        /*
         * get any return value
         */
        returndatacopy(0, 0, returndatasize())
        /*
         * return any return value or error back to the caller
         */
        switch result
        case 0 {
            revert(0, returndatasize())
        }
        default {
            return(0, returndatasize())
        }
    }
}
