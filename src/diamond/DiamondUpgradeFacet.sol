// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

interface IFacet {
    function functionSelectors() external view returns (bytes4[] memory);
}

/**
 * @title Reference implementation for upgrade function for
 *        ERC-8109 Diamonds, Simplified
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

    /**
     * @notice Data stored for each function selector
     * @dev Facet address of function selector
     *      Position of selector in the 'bytes4[] selectors' array
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
         * Array of all function selectors that can be called in the diamond
         */
        bytes4[] selectors;
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

    /**
     * @dev This error means that a function to replace exists in a
     *      facet other than the facet that was given to be replaced.
     */
    error CannotReplaceFunctionFromNonReplacementFacet(bytes4 _selector);

    function addFacets(address[] memory _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
        if (_facets.length == 0) {
            return;
        }
        uint32 selectorPosition = uint32(s.selectors.length);
        for (uint256 i; i < _facets.length; i++) {
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

    /**
     * @notice This struct is used to replace old facets with new facets.
     */
    struct FacetReplacement {
        address oldFacet;
        address newFacet;
    }

    function replaceFacets(FacetReplacement[] calldata _replaceFacets) internal {
        DiamondStorage storage s = getDiamondStorage();
        for (uint256 i; i < _replaceFacets.length; i++) {
            address oldFacet = _replaceFacets[i].oldFacet;
            address newFacet = _replaceFacets[i].newFacet;
            if (oldFacet == newFacet) {
                revert CannotReplaceFacetWithSameFacet(oldFacet);
            }
            bytes4[] memory oldSelectors = IFacet(oldFacet).functionSelectors();
            bytes4[] memory newSelectors = IFacet(newFacet).functionSelectors();
            if (oldSelectors.length == 0) {
                revert NoSelectorsForFacet(oldFacet);
            }
            if (newSelectors.length == 0) {
                revert NoSelectorsForFacet(newFacet);
            }
            FacetAndPosition storage facetAndPosition = s.facetAndPosition[oldSelectors[0]];
            if (facetAndPosition.facet != oldFacet) {
                revert FacetToReplaceDoesNotExist(oldFacet);
            }
            /**
             * If the first selector of newSelectors is different then update
             * s.selectors.
             */
            uint32 selectorPosition = facetAndPosition.position;
            if (newSelectors[0] != oldSelectors[0]) {
                s.selectors[selectorPosition] = newSelectors[0];
            }
            /**
             * Add or replace new selectors.
             */
            for (uint256 selectorIndex; selectorIndex < newSelectors.length; selectorIndex++) {
                bytes4 selector = newSelectors[selectorIndex];
                address facet = s.facetAndPosition[selector].facet;
                s.facetAndPosition[selector] = FacetAndPosition(newFacet, selectorPosition);
                if (facet == address(0)) {
                    emit DiamondFunctionAdded(selector, newFacet);
                } else if (facet == oldFacet) {
                    emit DiamondFunctionReplaced(selector, oldFacet, newFacet);
                } else {
                    revert CannotReplaceFunctionFromNonReplacementFacet(selector);
                }
            }
            /**
             * Remove old selectors that were not replaced.
             */
            for (uint256 selectorIndex; selectorIndex < oldSelectors.length; selectorIndex++) {
                bytes4 selector = oldSelectors[selectorIndex];
                address facet = s.facetAndPosition[selector].facet;
                if (facet == oldFacet) {
                    delete s.facetAndPosition[selector];
                }
            }
        }
    }

    function removeFacets(address[] calldata _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
        if (_facets.length == 0) {
            return;
        }
        uint256 selectorCount = s.selectors.length;
        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i];
            bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
            if (facetSelectors.length == 0) {
                revert NoSelectorsForFacet(facet);
            }
            bytes4 firstSelector = facetSelectors[0];
            FacetAndPosition storage facetAndPosition = s.facetAndPosition[firstSelector];
            if (facetAndPosition.facet != facet) {
                revert CannotRemoveFacetThatDoesNotExist(facet);
            }
            /**
             * Replace selector with last selector.
             */
            uint32 selectorPosition = facetAndPosition.position;
            selectorCount--;
            if (selectorPosition != selectorCount) {
                bytes4 lastSelector = s.selectors[selectorCount];
                s.selectors[selectorPosition] = lastSelector;
                s.facetAndPosition[lastSelector].position = selectorPosition;
            }
            s.selectors.pop();

            for (uint256 selectorIndex; selectorIndex < facetSelectors.length; selectorIndex++) {
                bytes4 selector = facetSelectors[selectorIndex];
                delete s.facetAndPosition[selector];
                emit DiamondFunctionRemoved(selector, facet);
            }
        }
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

    function functionSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](1);
        selectors[0] = DiamondUpgradeFacet.upgradeDiamond.selector;
    }
}
