// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

error NoSelectorsProvidedForFacet(address _facet);
error NoBytecodeAtAddress(address _contractAddress, string _message);
error RemoveFacetAddressMustBeZeroAddress(address _facet);
error IncorrectFacetCutAction(uint8 _action);
error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
error CannotReplaceImmutableFunction(bytes4 _selector);
error CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(bytes4 _selector);
error CannotReplaceFunctionThatDoesNotExists(bytes4 _selector);
error CannotRemoveFunctionThatDoesNotExist(bytes4 _selector);
error CannotRemoveImmutableFunction(bytes4 _selector);
error InitializationFunctionReverted(address _initializationContractAddress, bytes _calldata);

bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

/*
 * @notice Data stored for each function selector
 * @dev Facet address of function selector
 *      Position of selector in the 'bytes4[] selectors' array
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
     * Array of all function selectors that can be called in the diamond
     */
    bytes4[] selectors;
}

function getStorage() pure returns (DiamondStorage storage s) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

function addFunctions(address _facet, bytes4[] calldata _functionSelectors) {
    DiamondStorage storage s = getStorage();
    if (_facet.code.length == 0) {
        revert NoBytecodeAtAddress(_facet, "LibDiamond: Add facet has no code");
    }
    /**
     * The position to store the next selector in the selectors array
     */
    uint32 selectorPosition = uint32(s.selectors.length);
    for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
        bytes4 selector = _functionSelectors[selectorIndex];
        address oldFacet = s.facetAndPosition[selector].facet;
        if (oldFacet != address(0)) {
            revert CannotAddFunctionToDiamondThatAlreadyExists(selector);
        }
        s.facetAndPosition[selector] = FacetAndPosition(_facet, selectorPosition);
        s.selectors.push(selector);
        selectorPosition++;
    }
}

function replaceFunctions(address _facet, bytes4[] calldata _functionSelectors) {
    DiamondStorage storage s = getStorage();
    if (_facet.code.length == 0) {
        revert NoBytecodeAtAddress(_facet, "LibDiamond: Replace facet has no code");
    }
    for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
        bytes4 selector = _functionSelectors[selectorIndex];
        address oldFacet = s.facetAndPosition[selector].facet;
        /**
         * can't replace immutable functions -- functions defined directly in the diamond in this case
         */
        address diamondAddress;
        assembly {
            diamondAddress := address()
        }        
        if (oldFacet == diamondAddress) {
            revert CannotReplaceImmutableFunction(selector);
        }
        if (oldFacet == _facet) {
            revert CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet(selector);
        }
        if (oldFacet == address(0)) {
            revert CannotReplaceFunctionThatDoesNotExists(selector);
        }
        /**
         * replace old facet address
         */
        s.facetAndPosition[selector].facet = _facet;
    }
}

function removeFunctions(address _facet, bytes4[] calldata _functionSelectors) {
    DiamondStorage storage s = getStorage();
    uint256 selectorCount = s.selectors.length;
    if (_facet != address(0)) {
        revert RemoveFacetAddressMustBeZeroAddress(_facet);
    }
    for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
        bytes4 selector = _functionSelectors[selectorIndex];
        FacetAndPosition memory oldFacetAndPosition = s.facetAndPosition[selector];
        if (oldFacetAndPosition.facet == address(0)) {
            revert CannotRemoveFunctionThatDoesNotExist(selector);
        }
        /**
         * can't remove immutable functions -- functions defined directly in the diamond
         */
        address diamondAddress;
        assembly {
            diamondAddress := address()
        }
        if (oldFacetAndPosition.facet == diamondAddress) {
            revert CannotRemoveImmutableFunction(selector);
        }
        /**
         * replace selector with last selector
         */
        selectorCount--;
        if (oldFacetAndPosition.position != selectorCount) {
            bytes4 lastSelector = s.selectors[selectorCount];
            s.selectors[oldFacetAndPosition.position] = lastSelector;
            s.facetAndPosition[lastSelector].position = oldFacetAndPosition.position;
        }
        /**
         * delete last selector
         */
        s.selectors.pop();
        delete s.facetAndPosition[selector];
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

/*
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

/**
 * @notice Add/replace/remove any number of functions and optionally execute
 *         a function with delegatecall
 * @param _diamondCut Contains the facet addresses and function selectors
 * @param _init The address of the contract or facet to execute _calldata
 * @param _calldata A function call, including function selector and arguments
 *                  _calldata is executed with delegatecall on _init
 */
function diamondCut(FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) {
    for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
        bytes4[] calldata functionSelectors = _diamondCut[facetIndex].functionSelectors;
        address facetAddress = _diamondCut[facetIndex].facetAddress;
        if (functionSelectors.length == 0) {
            revert NoSelectorsProvidedForFacet(facetAddress);
        }
        FacetCutAction action = _diamondCut[facetIndex].action;
        if (action == FacetCutAction.Add) {
            addFunctions(facetAddress, functionSelectors);
        } else if (action == FacetCutAction.Replace) {
            replaceFunctions(facetAddress, functionSelectors);
        } else if (action == FacetCutAction.Remove) {
            removeFunctions(facetAddress, functionSelectors);
        } else {
            revert IncorrectFacetCutAction(uint8(action));
        }
    }
    emit DiamondCut(_diamondCut, _init, _calldata);

    /**
     * Initialize the diamond cut
     */
    if (_init == address(0)) {
        return;
    }
    if (_init.code.length == 0) {
        revert NoBytecodeAtAddress(_init, "LibDiamond: _init address no code");
    }
    (bool success, bytes memory error) = _init.delegatecall(_calldata);
    if (!success) {
        if (error.length > 0) {
            /*
             * bubble up error
             */
            assembly ("memory-safe") {
                revert(add(error, 0x20), mload(error))
            }
        } else {
            revert InitializationFunctionReverted(_init, _calldata);
        }
    }
}
