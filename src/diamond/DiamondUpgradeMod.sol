// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * Reference implementation for upgrade function for ERC-8109 Diamonds, Simplified
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
 * Only the first FacetNode of each facet is used to link facets.
 *     * prevFacetNode - Is the selector of the first FacetNode of the previous
 *       facet.
 *     * nextFacetNode - Is the selector of the first FacetNode of the next
 *       facet.
 *
 * Here is a example that shows the structor:
 *
 * FacetList
 *   facetCount      = 3
 *   firstFacetNode  = selector1   // facetA
 *   lastFacetNode   = selector7   // facetC
 *
 * facetNodes mapping (selector => FacetNode)
 *
 *   selector   facet    prevFacetNode   nextFacetNode
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
 * - Any values in "prevFacetNode" in non-first FacetNodes are ignored.
 */

bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

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
 * @dev This function never sets `facetList.firstFacetNode` because that is expected
 *      to happen during deployment of the diamond. This function assumes at least one
 *      function has already been added to the diamond.
 */
function addFacets(address[] calldata _facets) {
    DiamondStorage storage s = getStorage();
    if (_facets.length == 0) {
        return;
    }
    FacetList memory facetList = s.facetList;
    bytes4 prevFacetNode = facetList.lastFacetNode;
    bytes4 currentSelector;
    for (uint256 i; i < _facets.length; i++) {
        address facet = _facets[0];
        bytes4[] memory facetSelectors = functionSelectors(facet);
        unchecked {
            facetList.selectorCount += uint32(facetSelectors.length);
        }
        currentSelector = facetSelectors[0];
        s.facetNodes[prevFacetNode].nextFacetNode = currentSelector;
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

/**
 * @notice This struct is used to replace old facets with new facets.
 */
struct FacetReplacement {
    address oldFacet;
    address newFacet;
}

function replaceFacets(FacetReplacement[] calldata _replaceFacets) {
    DiamondStorage storage s = getStorage();
    FacetList memory facetList = s.facetList;
    for (uint256 i; i < _replaceFacets.length; i++) {
        address oldFacet = _replaceFacets[i].oldFacet;
        address newFacet = _replaceFacets[i].newFacet;
        if (oldFacet == newFacet) {
            revert CannotReplaceFacetWithSameFacet(oldFacet);
        }
        bytes4[] memory oldSelectors = functionSelectors(oldFacet);
        bytes4[] memory newSelectors = functionSelectors(newFacet);
        bytes4 oldSelector = oldSelectors[0];
        bytes4 newSelector = newSelectors[0];
        FacetNode storage firstFacetNode = s.facetNodes[oldSelector];
        if (firstFacetNode.facet != oldFacet) {
            revert FacetToReplaceDoesNotExist(oldFacet);
        }
        bytes4 prevFacetNode = firstFacetNode.prevFacetNode;
        bytes4 nextFacetNode = firstFacetNode.nextFacetNode;
        /**
         * Set the facet node for the new selector.
         */
        s.facetNodes[newSelector] = FacetNode(newFacet, prevFacetNode, nextFacetNode);
        /**
         * Adjust facet list if needed and emit appropriate function event
         */
        if (oldSelector != newSelector) {
            if (oldSelector == facetList.firstFacetNode) {
                facetList.firstFacetNode = newSelector;
            } else {
                s.facetNodes[prevFacetNode].nextFacetNode = newSelector;
            }
            if (oldSelector == facetList.lastFacetNode) {
                facetList.lastFacetNode = newSelector;
            } else {
                s.facetNodes[nextFacetNode].prevFacetNode = newSelector;
            }
            delete s.facetNodes[oldSelector];
            emit DiamondFunctionRemoved(oldSelector, oldFacet);
            emit DiamondFunctionAdded(newSelector, newFacet);
        } else {
            emit DiamondFunctionReplaced(newSelector, oldFacet, newFacet);
        }
        /**
         * Add or replace new selectors.
         */
        for (uint256 selectorIndex = 1; selectorIndex < newSelectors.length; selectorIndex++) {
            bytes4 selector = newSelectors[selectorIndex];
            address facet = s.facetNodes[selector].facet;
            s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
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
        }
        /**
         * Remove old selectors that were not replaced.
         */
        for (uint256 selectorIndex = 1; selectorIndex < oldSelectors.length; selectorIndex++) {
            bytes4 selector = oldSelectors[selectorIndex];
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

function removeFacets(address[] calldata _facets) {
    DiamondStorage storage s = getStorage();
    FacetList memory facetList = s.facetList;
    for (uint256 i = 0; i < _facets.length; i++) {
        address facet = _facets[i];
        bytes4[] memory facetSelectors = functionSelectors(facet);
        unchecked {
            facetList.selectorCount -= uint32(facetSelectors.length);
        }
        bytes4 currentSelector = facetSelectors[0];
        FacetNode storage facetNode = s.facetNodes[currentSelector];
        if (facetNode.facet != facet) {
            revert CannotRemoveFacetThatDoesNotExist(facet);
        }
        /**
         * Remove the facet from the linked list.
         */
        bytes4 nextFacetNode = facetNode.nextFacetNode;
        bytes4 prevFacetNode = facetNode.prevFacetNode;
        if (currentSelector == facetList.firstFacetNode) {
            facetList.firstFacetNode = nextFacetNode;
        } else {
            s.facetNodes[facetNode.prevFacetNode].nextFacetNode = nextFacetNode;
        }
        if (currentSelector == facetList.lastFacetNode) {
            facetList.lastFacetNode = prevFacetNode;
        } else {
            s.facetNodes[nextFacetNode].prevFacetNode = prevFacetNode;
        }
        /**
         * Remove facet selectors.
         */
        for (uint256 selectorIndex; selectorIndex < facetSelectors.length; selectorIndex++) {
            bytes4 selector = facetSelectors[selectorIndex];
            delete s.facetNodes[selector];
            emit DiamondFunctionRemoved(selector, facet);
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
