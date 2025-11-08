// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title Kitetsu-Dinesh Diamond Loupe Facet Implementation
/// @notice Adapts @0xkitetsu-dinesh's bucket-chaining strategy for Compose benchmarks
/// @dev Uses the same diamond storage layout as other Compose benchmark loupes
contract KitetsuDineshDiamondLoupeFacet {
    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    struct DiamondStorage {
        mapping(bytes4 => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
    }

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    struct BucketNode {
        address[5] entries;
        uint16 next;
    }

    function getStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function facetAddress(bytes4 selector) external view returns (address facet) {
        DiamondStorage storage ds = getStorage();
        facet = ds.facetAndPosition[selector].facet;
    }

    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory selectors) {
        DiamondStorage storage ds = getStorage();
        bytes4[] memory allSelectors = ds.selectors;
        uint256 total = allSelectors.length;

        // First pass - count selectors for facet
        uint256 count;
        for (uint256 i; i < total; i++) {
            if (ds.facetAndPosition[allSelectors[i]].facet == facet) {
                unchecked {
                    ++count;
                }
            }
        }

        selectors = new bytes4[](count);
        if (count == 0) return selectors;

        // Second pass - populate array
        uint256 cursor;
        for (uint256 i; i < total; i++) {
            bytes4 sel = allSelectors[i];
            if (ds.facetAndPosition[sel].facet == facet) {
                selectors[cursor] = sel;
                unchecked {
                    ++cursor;
                }
            }
        }
    }

    function facetAddresses() public view returns (address[] memory allFacets) {
        DiamondStorage storage ds = getStorage();
        bytes4[] memory selectors = ds.selectors;
        uint256 selectorsCount = selectors.length;
        if (selectorsCount == 0) return new address[](0);

        address[] memory uniqueFacets = new address[](selectorsCount);
        BucketNode[] memory nodes = new BucketNode[](selectorsCount);
        uint16[256] memory heads;
        uint16 nodeCount;
        uint256 uniqueCount;

        for (uint256 selIdx; selIdx < selectorsCount; selIdx++) {
            address facet = ds.facetAndPosition[selectors[selIdx]].facet;
            uint16 key = uint16(uint160(facet) & 0xff);
            uint16 current = heads[key];
            uint16 previous = 0;
            bool placed;

            while (current != 0 && !placed) {
                uint16 nodeIndex = current - 1;
                BucketNode memory node = nodes[uint256(nodeIndex)];

                for (uint256 slot; slot < 5; slot++) {
                    address entry = node.entries[slot];
                    if (entry == facet) {
                        placed = true;
                        break;
                    }
                    if (entry == address(0)) {
                        node.entries[slot] = facet;
                        nodes[uint256(nodeIndex)] = node;
                        uniqueFacets[uniqueCount++] = facet;
                        placed = true;
                        break;
                    }
                }

                if (placed) {
                    break;
                }

                if (node.next == 0) {
                    previous = current;
                    current = 0;
                } else {
                    previous = current;
                    current = node.next;
                }
            }

            if (!placed) {
                BucketNode memory newNode;
                newNode.entries[0] = facet;
                nodes[uint256(nodeCount)] = newNode;
                uint16 newIndex = nodeCount + 1;

                if (heads[key] == 0) {
                    heads[key] = newIndex;
                } else {
                    if (previous == 0) {
                        previous = heads[key];
                    }
                    BucketNode memory prevNode = nodes[uint256(previous - 1)];
                    prevNode.next = newIndex;
                    nodes[uint256(previous - 1)] = prevNode;
                }

                uniqueFacets[uniqueCount++] = facet;
                nodeCount = newIndex;
            }
        }

        allFacets = new address[](uniqueCount);
        for (uint256 i; i < uniqueCount; i++) {
            allFacets[i] = uniqueFacets[i];
        }
    }

    function facets() external view returns (Facet[] memory facetData) {
        address[] memory facetsList = facetAddresses();
        uint256 numFacets = facetsList.length;
        facetData = new Facet[](numFacets);

        for (uint256 i; i < numFacets; i++) {
            address facetAddr = facetsList[i];
            bytes4[] memory selectors = this.facetFunctionSelectors(facetAddr);
            facetData[i] = Facet({facet: facetAddr, functionSelectors: selectors});
        }
    }
}

