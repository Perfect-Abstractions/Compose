// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

interface IFacet {
    function packedSelectors() external view returns (bytes memory);
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
     * @notice Decodes a packed byte stream into a standard bytes4[] array.
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
        facetSelectors = unpackSelectors(IFacet(_facet).packedSelectors());
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
        bytes4 currentSelector = facetList.firstFacetNodeId;
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
        bytes4 currentSelector = facetList.firstFacetNodeId;
        facetsAndSelectors = new Facet[](facetList.facetCount);
        for (uint256 i; i < facetList.facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            bytes4[] memory facetSelectors = unpackSelectors(IFacet(facet).packedSelectors());
            facetsAndSelectors[i].facet = facet;
            facetsAndSelectors[i].functionSelectors = facetSelectors;
            currentSelector = s.facetNodes[currentSelector].nextFacetNodeId;
        }
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
        pairs = new FunctionFacetPair[](facetList.selectorCount);
        bytes4 currentSelector = facetList.firstFacetNodeId;
        uint256 selectorCount;
        for (uint256 i; i < facetList.facetCount; i++) {
            address facet = s.facetNodes[currentSelector].facet;
            bytes memory selectors = IFacet(facet).packedSelectors();
            uint256 selectorLength;
            unchecked {
                selectorLength = selectors.length / 4;
            }
            for (uint256 selectorIndex; selectorIndex < selectorLength; selectorIndex++) {
                bytes4 selector = at(selectors, selectorIndex);
                pairs[selectorCount] = FunctionFacetPair(selector, facet);
                unchecked {
                    selectorCount++;
                }
            }
            currentSelector = s.facetNodes[currentSelector].nextFacetNodeId;
        }
    }

    function packedSelectors() external pure returns (bytes memory) {
        return bytes.concat(
            this.facetAddress.selector,
            this.facetFunctionSelectors.selector,
            this.facetAddresses.selector,
            this.facets.selector,
            this.functionFacetPairs.selector
        );
    }
}
