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
     * @notice Data stored for each function selector
     * @dev Facet address of function selector
     *      Position of selector in the 'bytes4[] selectors' array
     */
    struct FacetNode {
        address facet;
        bytes4 prevFacetSelector;
        bytes4 nextFacetSelector;
    }

    struct FacetList {
        uint32 facetCount;
        bytes4 firstFacetSelector;
        bytes4 lastFacetSelector;
    }

    /**
     * @custom:storage-location erc8042:erc8109.diamond
     */
    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetNode) facetNodes;
        FacetList facetList;
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
        facet = s.facetNodes[_functionSelector].facet;
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
        if (facetSelectors.length == 0 || s.facetNodes[facetSelectors[0]].facet == address(0)) {
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
        FacetList memory facetList = s.facetList;
        uint256 facetCount = facetList.facetCount;
        allFacets = new address[](facetCount);
        bytes4 currentSelector = facetList.firstFacetSelector;
        for (uint256 i; i < facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            allFacets[i] = facet;
            currentSelector = s.facetNodes[currentSelector].nextFacetSelector;
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
        FacetList memory facetList = s.facetList;
        uint256 facetCount = facetList.facetCount;
        bytes4 currentSelector = facetList.firstFacetSelector;
        facetsAndSelectors = new Facet[](facetCount);
        for (uint256 i; i < facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
            facetsAndSelectors[i].facet = facet;
            facetsAndSelectors[i].functionSelectors = facetSelectors;
            currentSelector = s.facetNodes[currentSelector].nextFacetSelector;
        }
    }

    struct FunctionFacetPair {
        bytes4 selector;
        address facet;
    }

    /**
     * @notice Returns an array of all function selectors and their
     *         corresponding facet addresses.
     *
     * @dev    Iterates through the diamond's stored selectors and pairs
     *         each with its facet.
     * @return pairs An array of `FunctionFacetPair` structs, each containing
     *         a selector and its facet address.
     */
    function functionFacetPairs() external view returns (FunctionFacetPair[] memory pairs) {
        DiamondStorage storage s = getStorage();
        FacetList memory facetList = s.facetList;
        uint256 facetCount = facetList.facetCount;
        bytes4 currentSelector = facetList.firstFacetSelector;
        uint256 selectorCount;
        Facet[] memory facetsAndSelectors = new Facet[](facetCount);
        for (uint256 i; i < facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            bytes4[] memory facetSelectors = IFacet(facet).functionSelectors();
            unchecked {
                selectorCount += facetSelectors.length;
            }
            facetsAndSelectors[i].facet = facet;
            facetsAndSelectors[i].functionSelectors = facetSelectors;
            currentSelector = s.facetNodes[currentSelector].nextFacetSelector;
        }
        pairs = new FunctionFacetPair[](selectorCount);
        selectorCount = 0;
        for (uint256 i; i < facetCount; i++) {
            Facet memory facetsAndSelector = facetsAndSelectors[i];
            address facet = facetsAndSelector.facet;
            uint256 selectorsLength = facetsAndSelector.functionSelectors.length;
            for (uint256 selectorIndex; selectorIndex < selectorsLength; selectorIndex++) {
                bytes4 selector = facetsAndSelector.functionSelectors[selectorIndex];
                pairs[selectorCount] = FunctionFacetPair(selector, facet);
                unchecked {
                    selectorCount++;
                }
            }
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
