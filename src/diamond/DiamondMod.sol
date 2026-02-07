// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
* @title Diamond Module
* @notice Internal functions and storage for diamond proxy functionality.
* @dev Follows EIP-2535 Diamond Standard
* (https://eips.ethereum.org/EIPS/eip-2535)
*/

interface IFacet {
    function packedSelectors() external pure returns (bytes memory);
}

bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

/**
 * @notice Data stored for each function selector
 * @dev Facet address of function selector
 *      Position of selector in the 'bytes4[] selectors' array
 */
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

function getStorage() pure returns (DiamondStorage storage s) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

error FunctionSelectorsCallFailed(address _facet);
error NoSelectorsForFacet(address _facet);
error NoBytecodeAtAddress(address _contractAddress);
error IncorrectSelectorsEncoding(address _facet);

/**
 * @notice Emitted when a function is added to a diamond.
 *
 * @param _selector The function selector being added.
 * @param _facet    The facet address that will handle calls to `_selector`.
 */
event DiamondFunctionAdded(bytes4 indexed _selector, address indexed _facet);

error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);

function packedSelectors(address _facet) view returns (bytes memory selectors) {
    (bool success, bytes memory data) = _facet.staticcall(abi.encodeWithSelector(IFacet.packedSelectors.selector));
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

function addFacets(address[] memory _facets) {
    DiamondStorage storage s = getStorage();
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
     * Then we emit the DiamondFunctionAdded event for the first selector. But don't actually add the first
     * selector to the diamond at this point because we don't have the nextFacetNodeId value for the facet yet.
     * We emit the DiamondFunctionAdded event at this point so the event order is consistent with the order of
     * selectors returned by the facet.
     *
     * All the selectors (except the first one) in the first facet are then added to the diamond.
     *
     * In the first iteration of the main facet loop the the selectors for the next facet are retrieved.
     * This makes available the nextFacetNodeId value that is needed to store the first selector of the
     * first facet. So then the first selector is stored.
     *
     * The main facet loop continues in a similar way, emitting the DiamondFunctionAdded for the first
     * selector of the facet, but not adding it, adding the other selectors, and in the next iteration adding
     * the first selector after nextFacetNodeId is available.
     *
     * After the main facet loop ends, the first selector from the last facet is added to the diamond.
     */

    bytes4 prevFacetNodeId = facetList.lastFacetNodeId;
    address facet = _facets[0];
    bytes memory selectors = packedSelectors(facet);
    /*
     * Shift right by 2 is the same as dividing by 4, but cheaper.
     * We do this to get the number of selectors
     */
    uint256 selectorsLength = selectors.length >> 2;
    unchecked {
        facetList.selectorCount += uint32(selectorsLength);
    }
    /*
     * currentFacetNodeId is the head node of the current facet.
     * We cannot write it to storage yet because we don't know the `next` pointer.
     */
    bytes4 currentFacetNodeId = at(selectors, 0);
    if (facetList.facetCount == 0) {
        facetList.firstFacetNodeId = currentFacetNodeId;
    } else {
        /*
         * Link the previous tail of the diamond to this new batch
         */
        s.facetNodes[prevFacetNodeId].nextFacetNodeId = currentFacetNodeId;
    }
    /*
     * Emit event for the first selector now to preserve order, even though storage write is deferred.
     */
    emit DiamondFunctionAdded(currentFacetNodeId, facet);
    /*
     * Add all selectors, except the first, to the diamond.
     */
    for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
        bytes4 selector = at(selectors, selectorIndex);
        if (s.facetNodes[selector].facet != address(0)) {
            revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
        }
        s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
        emit DiamondFunctionAdded(selector, facet);
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
     * 3. Updates facet values: facet = nextFacet, etc.
     * 4. Emits the DiamondFunctionAdded for facet's first selector.
     * 5. Adds all the selectors (except the first) to the diamond.
     * 6. Repeat loop.
     * Note: All selectors of a facet, except the first selector, are added the diamond. After that the first
     * selector is added. However the DiamondEvent event for the first selector is emitted before the rest of
     * the selectors. This maintains the order of events with the order given by facets.
     */
    for (uint256 i = 1; i < facetLength; i++) {
        address nextFacet = _facets[i];
        selectors = packedSelectors(nextFacet);
        /*
         * Shift right by 2 is the same as dividing by 4, but cheaper.
         * We do this to get the number of selectors.
         */
        selectorsLength = selectors.length >> 2;
        unchecked {
            facetList.selectorCount += uint32(selectorsLength);
        }
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
         * Here we emit the DiamondFunctionAdded event for for the first selector of the facet.
         * But we don't actually add the selector here.
         * The selector gets added in the next iteration of the loop when the nextFacetNodeId
         * value is available for it.
         */
        emit DiamondFunctionAdded(currentFacetNodeId, facet);
        /*
         * Add all the selectors of the facet to the diamond, except the first selector.
         */
        for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(selectors, selectorIndex);
            if (s.facetNodes[selector].facet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
            emit DiamondFunctionAdded(selector, facet);
        }
        /*
         * Restore Free Memory Pointer to reuse memory from packedSelector() calls.
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
    facetList.facetCount += uint32(facetLength);

    facetList.lastFacetNodeId = currentFacetNodeId;
    s.facetList = facetList;
}

error FunctionNotFound(bytes4 _selector);

/**
 * Find facet for function that is called and execute the
 * function if a facet is found and return any value.
 */
function diamondFallback() {
    DiamondStorage storage s = getStorage();
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
