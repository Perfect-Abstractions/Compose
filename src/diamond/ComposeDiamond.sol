// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

contract ComposeDiamond {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    /**
     * @notice Data stored for each function selector.
     * @dev Facet address of function selector.
     *      Position of selector in the `bytes4[] selectors` array.
     */
    struct FacetAndPosition {
        address facet;
        uint32 position;
    }

    /**
     * @custom:storage-location erc8042:compose.diamond
     */
    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        /**
         * `selectors` contains all function selectors that can be called in the diamond.
         */
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @dev Add=0, Replace=1, Remove=2
     */
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    /**
     * @notice Change in diamond
     * @dev facetAddress, the address of the facet containing the function selectors
     *      action, the type of action to perform on the functions (Add/Replace/Remove)
     *      functionSelectors, the selectors of the functions to add/replace/remove
     */
    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);

    error NoBytecodeAtAddress(address _contractAddress, string _message);
    error InvalidActionWhenDeployingDiamond(address facetAddress, FacetCutAction action, bytes4[] functionSelectors);
    error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);

    function addFacets(FacetCut[] memory _facets) internal {
        DiamondStorage storage s = getStorage();
        uint32 selectorPosition = uint32(s.selectors.length);
        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i].facetAddress;
            bytes4[] memory functionSelectors = _facets[i].functionSelectors;
            if (_facets[i].action != FacetCutAction.Add) {
                revert InvalidActionWhenDeployingDiamond(facet, _facets[i].action, functionSelectors);
            }
            if (facet.code.length == 0) {
                revert NoBytecodeAtAddress(facet, "ComposeDiamond: Add facet has no code");
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
            }
        }
        emit DiamondCut(_facets, address(0), "");
    }

    error FunctionNotFound(bytes4 _selector);

    /**
     * Find facet for function that is called and execute the
     * function if a facet is found and return any value.
     */
    fallback() external payable {
        DiamondStorage storage s = getStorage();
        /**
         * get facet from function selector
         */
        address facet = s.facetAndPosition[msg.sig].facet;
        if (facet == address(0)) {
            revert FunctionNotFound(msg.sig);
        }
        /**
         * Execute external function from facet using delegatecall and return any value.
         */
        assembly {
            /**
             * copy function selector and any arguments
             */
            calldatacopy(0, 0, calldatasize())
            /**
             * execute function call using the facet
             */
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            /**
             * get any return value
             */
            returndatacopy(0, 0, returndatasize())
            /**
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

    receive() external payable {}
}
