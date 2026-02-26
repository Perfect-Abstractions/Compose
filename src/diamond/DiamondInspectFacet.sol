// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

interface IFacet {
    function exportSelectors() external view returns (bytes memory);
}

contract DiamondInspectFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("erc8153.diamond");

    struct FacetNode {
        address facet;
        bytes4 prevFacetNodeId;
        bytes4 nextFacetNodeId;
    }

    struct FacetList {
        bytes4 headFacetNodeId;
        bytes4 tailFacetNodeId;
        uint32 facetCount;
        uint32 selectorCount;
    }

    /**
     * @custom:storage-location erc8042:erc8153.diamond
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
     * @notice Decodes a packed bytes array into a standard bytes4[] array.
     * @param packed The packed bytes (e.g., from `bytes.concat`).
     * @return unpacked The standard padded bytes4[] array.
     */
    function unpackSelectors(bytes memory packed) internal pure returns (bytes4[] memory unpacked) {
        /*
         * Allocate the output array
        */
        uint256 count = packed.length / 4;
        unpacked = new bytes4[](count);
        /*
         * Copy from packed to unpacked
        */
        assembly ("memory-safe") {
            /*
             * 'src' points to the start of the data in the packed array (skip 32-byte length)
            */
            let src := add(packed, 32)
            /*
             * 'dst' points to the start of the data in the new selectors array (skip 32-byte length)
             */
            let dst := add(unpacked, 32)
            /*
             * 'end' is the stopping point for the destination pointer
             */
            let end := add(dst, mul(count, 32))
            /*
             * While 'dst' is less than 'end', keep copying
            */
            for {} lt(dst, end) {} {
                /*
                 * A. Load 32 bytes from the packed source.
                 *    We read "dirty" data (neighboring bytes), but it doesn't matter
                 *    because we truncate it when writing.
                 */
                let value := mload(src)
                /*
                 * B. Clearn up the value to extract only the 4 bytes we want.
                 */
                value := and(value, 0xFFFFFFFF00000000000000000000000000000000000000000000000000000000)
                /*
                 * C. Store the value into the destination
                 */
                mstore(dst, value)
                /*
                 * D. Advance pointers
                 */
                src := add(src, 4) // Move forward 4 bytes in packed source
                dst := add(dst, 32) // Move forward 32 bytes in destination target
            }
        }
    }

    /**
     * @notice Gets the function selectors that are handled by the given facet.
     * @dev If facet is not found return empty array.
     * @param _facet The facet address.
     * @return facetSelectors The function selectors.
     */
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        facetSelectors = unpackSelectors(IFacet(_facet).exportSelectors());
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
        allFacets = new address[](facetList.facetCount);
        bytes4 currentSelector = facetList.headFacetNodeId;
        for (uint256 i; i < facetList.facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            allFacets[i] = facet;
            currentSelector = s.facetNodes[currentSelector].nextFacetNodeId;
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
        bytes4 currentSelector = facetList.headFacetNodeId;
        facetsAndSelectors = new Facet[](facetList.facetCount);
        for (uint256 i; i < facetList.facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            bytes4[] memory facetSelectors = unpackSelectors(IFacet(facet).exportSelectors());
            facetsAndSelectors[i].facet = facet;
            facetsAndSelectors[i].functionSelectors = facetSelectors;
            currentSelector = s.facetNodes[currentSelector].nextFacetNodeId;
        }
    }

    /**
     * @notice Exports the function selectors of the DiamondInspectFacet
     * @dev This function is use as a selector discovery mechanism for diamonds
     * @return selectors The exported function selectors of the DiamondInspectFacet
     */ 
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.facetAddress.selector,
            this.facetFunctionSelectors.selector,
            this.facetAddresses.selector,
            this.facets.selector
        );
    }
}
