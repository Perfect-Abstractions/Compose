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

/**
 * @notice Emitted when a function is added to a diamond.
 *
 * @param _selector The function selector being added.
 * @param _facet    The facet address that will handle calls to `_selector`.
 */
event DiamondFunctionAdded(bytes4 indexed _selector, address indexed _facet);

error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error NoFacetsToAdd();

function packedSelectors(address _facet) view returns (bytes memory) {
    if (_facet.code.length == 0) {
        revert NoBytecodeAtAddress(_facet);
    }
    (bool success, bytes memory selectors) =
        _facet.staticcall(abi.encodeWithSelector(bytes4(keccak256("packedSelectors()"))));

    if (success == false) {
        revert FunctionSelectorsCallFailed(_facet);
    }
    if (selectors.length < 4) {
        revert NoSelectorsForFacet(_facet);
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
    if (_facets.length == 0) {
        return;
    }
    FacetList memory facetList = s.facetList;
    bytes4 prevFacetNodeId = facetList.lastFacetNodeId;
    bytes memory selectors = packedSelectors(_facets[0]);
    bytes4 currentFacetNodeId = at(selectors, 0);
    if (facetList.facetCount == 0) {
        facetList.firstFacetNodeId = currentFacetNodeId;
    } else {
        s.facetNodes[prevFacetNodeId].nextFacetNodeId = currentFacetNodeId;
    }
    for (uint256 i; i < _facets.length; i++) {
        uint256 selectorsLength;
        uint256 nextI;
        unchecked {
            nextI = i + 1;
            selectorsLength = selectors.length / 4;
            facetList.selectorCount += uint32(selectorsLength);
        }
        bytes memory nextSelectors;
        bytes4 nextFacetNodeId;
        if (nextI < _facets.length) {
            nextSelectors = packedSelectors(_facets[nextI]);
            nextFacetNodeId = at(nextSelectors, 0);
        }
        address oldFacet = s.facetNodes[currentFacetNodeId].facet;
        if (oldFacet != address(0)) {
            revert CannotAddFunctionToDiamondThatAlreadyExists(currentFacetNodeId);
        }
        address facet = _facets[i];
        s.facetNodes[currentFacetNodeId] = FacetNode(facet, prevFacetNodeId, nextFacetNodeId);
        emit DiamondFunctionAdded(currentFacetNodeId, facet);

        for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
            bytes4 selector = at(selectors, selectorIndex);
            oldFacet = s.facetNodes[selector].facet;
            if (oldFacet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetNodes[selector] = FacetNode(facet, bytes4(0), bytes4(0));
            emit DiamondFunctionAdded(selector, facet);
        }
        prevFacetNodeId = currentFacetNodeId;
        selectors = nextSelectors;
        currentFacetNodeId = nextFacetNodeId;
    }
    unchecked {
        facetList.facetCount += uint32(_facets.length);
    }
    facetList.lastFacetNodeId = prevFacetNodeId;
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
