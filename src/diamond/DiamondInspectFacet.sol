// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

interface IFacet {
    function functionSelectors() external view returns (bytes4[] memory);
}

contract DiamondInspectFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8109.diamond");

    /**
     * @notice Data stored for each function selector.
     * @dev Facet address of function selector.
     *      Position of selector in the 'bytes4[] selectors' array.
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
         * Array of all function selectors that can be called in the diamond.
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
     * @notice Gets the facet address that handles the given selector.
     * @dev If facet is not found return address(0).
     * @param _functionSelector The function selector.
     * @return facet The facet address.
     */
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getStorage();
        facet = s.facetAndPosition[_functionSelector].facet;
    }

    /**
     * @notice Gets the function selectors that are handled by the given facet.
     * @dev If facet is not found return empty array.
     * @param _facet The facet address.
     * @return facetSelectors The function selectors.
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        facetSelectors = IFacet(_facet).functionSelectors();
        if (facetSelectors.length == 0 || s.facetAndPosition[facetSelectors[0]].facet == address(0)) {
            facetSelectors = new bytes4[](0);
        }
    }

    /**
     * @notice Gets the facet addresses used by the diamond.
     * @dev If no facets are registered return empty array.
     * @return allFacets The facet addresses.
     */
    function facetAddresses() external view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 facetCount = selectors.length;
        allFacets = new address[](facetCount);
        for (uint256 selectorIndex; selectorIndex < facetCount; selectorIndex++) {
            bytes4 selector = selectors[selectorIndex];
            address facet = s.facetAndPosition[selector].facet;
            allFacets[selectorIndex] = facet;
        }
    }

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    /**
     * @notice Returns the facet address and function selectors of all facets
     *         in the diamond.
     * @return facetsAndSelectors An array of Facet structs containing each
     *                            facet address and its function selectors.
     */
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 facetCount = selectors.length;
        facetsAndSelectors = new Facet[](facetCount);
        for (uint256 selectorIndex; selectorIndex < facetCount; selectorIndex++) {
            bytes4 selector = selectors[selectorIndex];
            address facet = s.facetAndPosition[selector].facet;
            bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
            facetsAndSelectors[selectorIndex].facet = facet;
            facetsAndSelectors[selectorIndex].functionSelectors = facetSelectors;
        }
    }

    function functionSelectors() external pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](4);
        selectors[0] = DiamondInspectFacet.facetAddress.selector;
        selectors[1] = DiamondInspectFacet.facetFunctionSelectors.selector;
        selectors[2] = DiamondInspectFacet.facetAddresses.selector;
        selectors[3] = DiamondInspectFacet.facets.selector;
    }
}
