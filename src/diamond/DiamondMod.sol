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

error NoSelectorsForFacet(address _facet);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error NoFacetsToAdd();

interface IFacet {
    function functionSelectors() external view returns (bytes4[] memory);
}

/**
 * @notice Adds facets and their function selectors to the diamond.
 */
function addFacets(address[] memory _facets) {
    DiamondStorage storage s = getStorage();
    uint256 facetsLength = _facets.length;
    if (facetsLength == 0) {
        revert NoFacetsToAdd();
    }
    uint32 selectorPosition = uint32(s.selectors.length);
    for (uint256 i; i < facetsLength; i++) {
        address facet = _facets[i];
        bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
        if (facetSelectors.length == 0) {
            revert NoSelectorsForFacet(facet);
        }
        s.selectors.push(facetSelectors[0]);
        for (uint256 selectorIndex; selectorIndex < facetSelectors.length; selectorIndex++) {
            bytes4 selector = facetSelectors[selectorIndex];
            address oldFacet = s.facetAndPosition[selector].facet;
            if (oldFacet != address(0)) {
                revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
            }
            s.facetAndPosition[selector] = FacetAndPosition(facet, selectorPosition);
            emit DiamondFunctionAdded(selector, facet);
        }
        selectorPosition++;
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
