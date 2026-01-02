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

/*
* @notice Data stored for each function selector.
* @dev Facet address of function selector.
*      Position of selector in the `bytes4[] selectors` array.
*/
struct FacetAndPosition {
    address facet;
    uint32 position;
}

/**
 * @custom:storage-location erc8042:erc8109.diamond
 */
struct DiamondStorage {
    mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
    /**
     * `selectors` contains all function selectors that can be called in the diamond.
     */
    bytes4[] selectors;
}

function getStorage() pure returns (DiamondStorage storage s) {
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

struct FacetFunctions {
    address facet;
    bytes4[] selectors;
}

error NoBytecodeAtAddress(address _contractAddress);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);

/**
 * @notice Adds facets and their function selectors to the diamond.
 * @dev Only supports adding functions during diamond deployment.
 */
function addFacets(FacetFunctions[] memory _facets) {
    DiamondStorage storage s = getStorage();
    uint32 selectorPosition = uint32(s.selectors.length);
    for (uint256 i; i < _facets.length; i++) {
        address facet = _facets[i].facet;
        bytes4[] memory functionSelectors = _facets[i].selectors;
        if (facet.code.length == 0) {
            revert NoBytecodeAtAddress(facet);
        }
        for (uint256 selectorIndex; selectorIndex < functionSelectors.length; selectorIndex++) {
            bytes4 selector = functionSelectors[selectorIndex];
            address oldFacet = s.facetAndPosition[selector].facet;
            if (oldFacet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetAndPosition[selector] = FacetAndPosition(facet, selectorPosition);
            s.selectors.push(selector);
            selectorPosition++;
            emit DiamondFunctionAdded(selector, facet);
        }
    }
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
    address facet = s.facetAndPosition[msg.sig].facet;
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
