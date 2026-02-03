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
    bytes4 prevFacetNode;
    bytes4 nextFacetNode;
}

struct FacetList {
    uint32 facetCount;
    uint32 selectorCount;
    bytes4 firstFacetNode;
    bytes4 lastFacetNode;
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

function functionSelectors(address _facet) view returns (bytes4[] memory) {
    if (_facet.code.length == 0) {
        revert NoBytecodeAtAddress(_facet);
    }
    (bool success, bytes memory data) =
        _facet.staticcall(abi.encodeWithSelector(bytes4(keccak256("functionSelectors()"))));

    if (success == false) {
        revert FunctionSelectorsCallFailed(_facet);
    }
    bytes4[] memory selectors = abi.decode(data, (bytes4[]));
    if (selectors.length == 0) {
        revert NoSelectorsForFacet(_facet);
    }
    return selectors;
}

/**
 * @notice Emitted when a function is added to a diamond.
 *
 * @param _selector The function selector being added.
 * @param _facet    The facet address that will handle calls to `_selector`.
 */
event DiamondFunctionAdded(bytes4 indexed _selector, address indexed _facet);

error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error NoFacetsToAdd();

/**
 * @notice Adds facets and their function selectors to the diamond.
 */
function addFacets(address[] memory _facets) {
    DiamondStorage storage s = getStorage();
    if (_facets.length == 0) {
        return;
    }
    FacetList memory facetList = s.facetList;
    bytes4 prevFacetNode = facetList.lastFacetNode;
    bytes4 currentSelector;
    for (uint256 i; i < _facets.length; i++) {
        address facet = _facets[i];
        bytes4[] memory facetSelectors = functionSelectors(facet);
        unchecked {
            facetList.selectorCount += uint32(facetSelectors.length);
        }
        currentSelector = facetSelectors[0];
        if (i == 0 && facetList.facetCount == 0) {
            facetList.firstFacetNode = currentSelector;
        } else {
            s.facetNodes[prevFacetNode].nextFacetNode = currentSelector;
        }
        for (uint256 selectorIndex; selectorIndex < facetSelectors.length; selectorIndex++) {
            bytes4 selector = facetSelectors[selectorIndex];
            address oldFacet = s.facetNodes[selector].facet;
            if (oldFacet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetNodes[selector] = FacetNode(facet, prevFacetNode, bytes4(0));
            emit DiamondFunctionAdded(selector, facet);
        }
        prevFacetNode = currentSelector;
    }
    unchecked {
        facetList.facetCount += uint32(_facets.length);
    }
    facetList.lastFacetNode = currentSelector;
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
