// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title Reference implementation for upgrade function for
 *        ERC-8109 Diamonds, Simplified
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
 * Here is a example that shows the structor:
 *
 * FacetList
 *   facetCount          = 3
 *   firstFacetNodeId  = selector1   // facetA
 *   lastFacetNodeId   = selector7   // facetC
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
 */
contract DiamondUpgradeFacet {
    /**
     * @notice Thrown when a non-owner attempts an action restricted to owner.
     */
    error OwnerUnauthorizedAccount();

    bytes32 constant OWNER_STORAGE_POSITION = keccak256("erc173.owner");

    /**
     * @custom:storage-location erc8042:erc8109.owner
     */
    struct OwnerStorage {
        address owner;
    }

    /**
     * @notice Returns a pointer to the owner storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The OwnerStorage struct in storage.
     */
    function getOwnerStorage() internal pure returns (OwnerStorage storage s) {
        bytes32 position = OWNER_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

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

    function getDiamondStorage() internal pure returns (DiamondStorage storage s) {
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

    function packedSelectors(address _facet) internal view returns (bytes memory) {
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

    function at(bytes memory selectors, uint256 index) internal pure returns (bytes4 selector) {
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

    function addFacets(address[] calldata _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
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

    /**
     * @notice This struct is used to replace old facets with new facets.
     */
    struct FacetReplacement {
        address oldFacet;
        address newFacet;
    }

    function replaceFacets(FacetReplacement[] calldata _replaceFacets) internal {
        DiamondStorage storage s = getDiamondStorage();
        FacetList memory facetList = s.facetList;
        for (uint256 i; i < _replaceFacets.length; i++) {
            address oldFacet = _replaceFacets[i].oldFacet;
            address newFacet = _replaceFacets[i].newFacet;
            if (oldFacet == newFacet) {
                revert CannotReplaceFacetWithSameFacet(oldFacet);
            }
            bytes memory oldSelectors = packedSelectors(oldFacet);
            bytes memory newSelectors = packedSelectors(newFacet);
            bytes4 oldCurrentFacetNodeId = at(oldSelectors, 0);
            bytes4 newCurrentFacetNodeId = at(newSelectors, 0);
            uint256 selectorsLength;
            /**
             * Validate old facet exists.
             */
            bytes4 prevFacetNodeId;
            bytes4 nextFacetNodeId;
            {
                FacetNode storage oldFacetNode = s.facetNodes[oldCurrentFacetNodeId];
                if (oldFacetNode.facet != oldFacet) {
                    revert FacetToReplaceDoesNotExist(oldFacet);
                }
                prevFacetNodeId = oldFacetNode.prevFacetNodeId;
                nextFacetNodeId = oldFacetNode.nextFacetNodeId;
                if (keccak256(oldSelectors) == keccak256(newSelectors)) {
                    /**
                     * Same selectors, replace.
                     */
                    emit DiamondFunctionReplaced(newCurrentFacetNodeId, oldFacet, newFacet);
                    s.facetNodes[newCurrentFacetNodeId] = FacetNode(newFacet, prevFacetNodeId, nextFacetNodeId);
                    /**
                     * Replace remaining selectors.
                     */
                    unchecked {
                        selectorsLength = newSelectors.length / 4;
                    }
                    for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
                        bytes4 selector = at(newSelectors, selectorIndex);
                        emit DiamondFunctionReplaced(selector, oldFacet, newFacet);
                        s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
                    }
                    continue;
                }
            }

            if (oldCurrentFacetNodeId != newCurrentFacetNodeId) {
                /**
                 * Write first selector with linking info, then process remaining.
                 */
                address facet = s.facetNodes[newCurrentFacetNodeId].facet;
                if (facet == address(0)) {
                    emit DiamondFunctionAdded(newCurrentFacetNodeId, newFacet);
                    unchecked {
                        facetList.selectorCount++;
                    }
                } else if (facet == oldFacet) {
                    emit DiamondFunctionReplaced(newCurrentFacetNodeId, oldFacet, newFacet);
                } else {
                    revert CannotAddFunctionToDiamondThatAlreadyExists(newCurrentFacetNodeId);
                }
                /**
                 * Update linked list.
                 */
                if (oldCurrentFacetNodeId == facetList.firstFacetNodeId) {
                    facetList.firstFacetNodeId = newCurrentFacetNodeId;
                } else {
                    s.facetNodes[prevFacetNodeId].nextFacetNodeId = newCurrentFacetNodeId;
                }
                if (oldCurrentFacetNodeId == facetList.lastFacetNodeId) {
                    facetList.lastFacetNodeId = newCurrentFacetNodeId;
                } else {
                    s.facetNodes[nextFacetNodeId].prevFacetNodeId = newCurrentFacetNodeId;
                }
            } else {
                /**
                 * Same first selector, just replace in place.
                 */
                emit DiamondFunctionReplaced(newCurrentFacetNodeId, oldFacet, newFacet);
            }
            s.facetNodes[newCurrentFacetNodeId] = FacetNode(newFacet, prevFacetNodeId, nextFacetNodeId);

            /**
             * Add or replace new selectors.
             */
            unchecked {
                selectorsLength = newSelectors.length / 4;
            }
            for (uint256 selectorIndex = 1; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(newSelectors, selectorIndex);
                address facet = s.facetNodes[selector].facet;
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
                s.facetNodes[selector] = FacetNode(newFacet, bytes4(0), bytes4(0));
            }
            /**
             * Remove old selectors that were not replaced.
             */
            unchecked {
                selectorsLength = oldSelectors.length / 4;
            }
            for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(oldSelectors, selectorIndex);
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

    function removeFacets(address[] calldata _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
        FacetList memory facetList = s.facetList;
        for (uint256 i = 0; i < _facets.length; i++) {
            address facet = _facets[i];
            bytes memory selectors = packedSelectors(facet);
            uint256 selectorsLength;
            unchecked {
                selectorsLength = selectors.length / 4;
                facetList.selectorCount -= uint32(selectorsLength);
            }
            bytes4 currentFacetNodeId = at(selectors, 0);
            FacetNode storage facetNode = s.facetNodes[currentFacetNodeId];
            if (facetNode.facet != facet) {
                revert CannotRemoveFacetThatDoesNotExist(facet);
            }
            /**
             * Remove the facet from the linked list.
             */
            bytes4 nextFacetNodeId = facetNode.nextFacetNodeId;
            bytes4 prevFacetNodeId = facetNode.prevFacetNodeId;
            if (currentFacetNodeId == facetList.firstFacetNodeId) {
                facetList.firstFacetNodeId = nextFacetNodeId;
            } else {
                s.facetNodes[prevFacetNodeId].nextFacetNodeId = nextFacetNodeId;
            }
            if (currentFacetNodeId == facetList.lastFacetNodeId) {
                facetList.lastFacetNodeId = prevFacetNodeId;
            } else {
                s.facetNodes[nextFacetNodeId].prevFacetNodeId = prevFacetNodeId;
            }
            /**
             * Remove facet selectors.
             */
            for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = at(selectors, selectorIndex);
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
    ) external {
        if (getOwnerStorage().owner != msg.sender) {
            revert OwnerUnauthorizedAccount();
        }
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

    function packedSelectors() external pure returns (bytes memory) {
        return bytes.concat(DiamondUpgradeFacet.upgradeDiamond.selector);
    }
}
