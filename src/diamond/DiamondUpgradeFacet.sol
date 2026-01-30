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
 *
 * @dev Compile this with the Solidity optimizer enabled or you may get a
 *      "stack too deep" error.
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
     * @notice Emitted when a facet is added to a diamond.
     * @param _facet The address of the facet added.
     */
    event FacetAdded(address indexed _facet);

    /**
     * @notice Emitted when replacing a facet with another facet.
     *
     * @param _oldFacet The address of the facet removed.
     * @param _newFacet The address of the facet added.
     */
    event FacetReplaced(address indexed _oldFacet, address indexed _newFacet);

    /**
     * @notice Emitted when a facet is removed from a diamond.
     *
     * @param _facet The address of the facet removed.
     */
    event FacetRemoved(address indexed _facet);

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
     * @notice The functions below detect and revert with the following errors.
     */
    error NoSelectorsForFacet(address _facet);
    error NoBytecodeAtAddress(address _contractAddress);
    error CannotAddFunctionToDiamondThatAlreadyExists(bytes4 _selector);
    error CannotRemoveFacetThatDoesNotExist(address _facet);
    error CannotReplaceFacetWithSameFacet(address _facet);
    error FacetToReplaceDoesNotExist(address _oldFacet);
    error CannotReplaceFunctionFromNonReplacementFacet(bytes4 _selector);
    error DelegateCallReverted(address _delegate, bytes _delegateCalldata);

    function addFacets(address[] memory _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
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
            }
            selectorPosition++;
            emit FacetAdded(facet);
        }
    }

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
            address facet = facetAndPosition.facet;
            uint32 selectorPosition = facetAndPosition.position;
            if (facet != oldFacet) {
                revert FacetToReplaceDoesNotExist(oldFacet);
            }
            /**
             * If the first selector of newSelectors is different then update
             * s.selectors.
             */
            if (newSelectors[0] != oldSelectors[0]) {
                s.selectors[selectorPosition] = newSelectors[0];
            }
            /**
             * Add or replace new selectors.
             */
            for (uint256 selectorIndex; selectorIndex < newSelectors.length; selectorIndex++) {
                bytes4 selector = newSelectors[selectorIndex];
                facet = s.facetAndPosition[selector].facet;
                if (facet == address(0) || facet == oldFacet) {
                    s.facetAndPosition[selector] = FacetAndPosition(newFacet, selectorPosition);
                } else {
                    revert CannotReplaceFunctionFromNonReplacementFacet(selector);
                }
            }
            /**
             * Remove old selectors that were not replaced.
             */
            for (uint256 selectorIndex; selectorIndex < oldSelectors.length; selectorIndex++) {
                bytes4 selector = oldSelectors[selectorIndex];
                facet = s.facetAndPosition[selector].facet;
                if (facet == oldFacet) {
                    delete s.facetAndPosition[selector];
                }
            }
            emit FacetReplaced(oldFacet, newFacet);
        }
    }

    function removeFacets(address[] calldata _facets) internal {
        DiamondStorage storage s = getDiamondStorage();
        uint256 selectorCount = s.selectors.length;
        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i];
            bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
            if (facetSelectors.length == 0) {
                revert NoSelectorsForFacet(facet);
            }
            bytes4 firstSelector = facetSelectors[0];
            FacetAndPosition storage facetAndPosition = s.facetAndPosition[firstSelector];
            address existingFacet = facetAndPosition.facet;
            uint32 selectorPosition = facetAndPosition.position;
            if (existingFacet != facet) {
                revert CannotRemoveFacetThatDoesNotExist(facet);
            }
            /**
             * Replace selector with last selector.
             */
            selectorCount--;
            if (selectorPosition != selectorCount) {
                bytes4 lastSelector = s.selectors[selectorCount];
                s.selectors[selectorPosition] = lastSelector;
                s.facetAndPosition[lastSelector].position = selectorPosition;
            }
            s.selectors.pop();
            delete s.facetAndPosition[firstSelector];

            for (uint256 selectorIndex = 1; selectorIndex < facetSelectors.length; selectorIndex++) {
                bytes4 selector = facetSelectors[selectorIndex];
                delete s.facetAndPosition[selector];
            }
            emit FacetRemoved(facet);
        }
    }

    /**
     * @notice Upgrade the diamond by adding, replacing, or removing facets.
     *
     * @dev
     * ### Facet Changes:
     * - `_addFacets` maps new selectors to their facet implementations.
     * - `_replaceFacets` replaces existing selectors from old facets with
     *                    selectors from new facets.
     * - `_removeFacets` removes selectors from facets.
     *
     * Facets are added first, then replaced, then removed.
     *
     * These events are emitted to record facet changes:
     * - `FacetAdded(address indexed _facet)`
     * - `FacetReplaced(address indexed _oldFacet, address indexed _newFacet)`
     * - `FacetRemoved(address indexed _facet)`
     *
     * ### DelegateCall:
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
     * ### Metadata:
     * If _tag is non-zero or if _metadata.length > 0 then the
     * `DiamondMetadata` event is emitted.
     *
     * @param _addFacets        Facets to add.
     * @param _replaceFacets    Facets to replace, array of (oldFacet, newFacet) pairs.
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
