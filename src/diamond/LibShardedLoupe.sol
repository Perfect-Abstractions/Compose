// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibBlob} from "../libraries/LibBlob.sol";

/// @title LibShardedLoupe
/// @notice Library for managing sharded diamond loupe data with SSTORE2 snapshots
library LibShardedLoupe {
    bytes32 constant SHARDED_LOUPE_STORAGE_POSITION = keccak256("compose.sharded.loupe");

    /// @notice Shard data structure containing blob pointers and counts
    struct Shard {
        address facetsBlob; // SSTORE2 blob with packed facet addresses
        address selectorsBlob; // SSTORE2 blob with packed selectors data
        uint32 facetCount;
        uint32 selectorCount;
    }

    /// @custom:storage-location erc8042:compose.sharded.loupe
    struct ShardedLoupeStorage {
        mapping(bytes32 categoryId => Shard) shards;
        bytes32[] categories;
        bool enabled; // Flag to enable/disable sharded loupe
    }

    function getStorage() internal pure returns (ShardedLoupeStorage storage s) {
        bytes32 position = SHARDED_LOUPE_STORAGE_POSITION;
        assembly ("memory-safe") {
            s.slot := position
        }
    }

    /// @notice Rebuild a shard with new facet and selector data
    /// @param categoryId The category identifier for this shard
    /// @param facets Array of facet addresses
    /// @param selectors Array of selector arrays (one per facet)
    function rebuildShard(bytes32 categoryId, address[] memory facets, bytes4[][] memory selectors) internal {
        ShardedLoupeStorage storage s = getStorage();

        // Pack facet addresses
        bytes memory packedFacets = abi.encodePacked(uint32(facets.length));
        for (uint256 i; i < facets.length; i++) {
            packedFacets = bytes.concat(packedFacets, abi.encodePacked(facets[i]));
        }
        address facetsBlob = LibBlob.write(packedFacets);

        // Pack selectors with their facet mappings
        bytes memory packedSel = abi.encodePacked(uint32(facets.length));
        uint32 totalSelectors;
        for (uint256 i; i < facets.length; i++) {
            packedSel = bytes.concat(
                packedSel, abi.encodePacked(facets[i], uint32(selectors[i].length))
            );
            for (uint256 j; j < selectors[i].length; j++) {
                packedSel = bytes.concat(packedSel, abi.encodePacked(selectors[i][j]));
            }
            totalSelectors += uint32(selectors[i].length);
        }
        address selectorsBlob = LibBlob.write(packedSel);

        // Store the shard
        s.shards[categoryId] =
            Shard({facetsBlob: facetsBlob, selectorsBlob: selectorsBlob, facetCount: uint32(facets.length), selectorCount: totalSelectors});

        // Add category if not already present
        bool found = false;
        for (uint256 i; i < s.categories.length; i++) {
            if (s.categories[i] == categoryId) {
                found = true;
                break;
            }
        }
        if (!found) {
            s.categories.push(categoryId);
        }
    }

    /// @notice Unpack addresses from a packed blob
    /// @param packed The packed bytes containing addresses
    /// @param output The output array to fill
    /// @param startIndex The starting index in output array
    /// @return nextIndex The next available index after unpacking
    function unpackAddresses(bytes memory packed, address[] memory output, uint256 startIndex)
        internal
        pure
        returns (uint256 nextIndex)
    {
        if (packed.length < 4) return startIndex;
        
        uint32 count;
        assembly ("memory-safe") {
            count := shr(224, mload(add(packed, 0x20)))
        }

        uint256 offset = 4;
        for (uint256 i; i < count; i++) {
            address addr;
            assembly ("memory-safe") {
                addr := shr(96, mload(add(add(packed, 0x20), offset)))
            }
            output[startIndex + i] = addr;
            offset += 20;
        }
        return startIndex + count;
    }

    /// @notice Unpack selectors and append to output arrays
    /// @param packed The packed bytes containing selector data
    /// @return facets Array of facet addresses
    /// @return selectors Array of selector arrays (one per facet)
    function unpackFacetsAndSelectors(bytes memory packed)
        internal
        pure
        returns (address[] memory facets, bytes4[][] memory selectors)
    {
        if (packed.length < 4) {
            return (new address[](0), new bytes4[][](0));
        }

        uint32 facetCount;
        assembly ("memory-safe") {
            facetCount := shr(224, mload(add(packed, 0x20)))
        }

        facets = new address[](facetCount);
        selectors = new bytes4[][](facetCount);

        uint256 offset = 4;
        for (uint256 i; i < facetCount; i++) {
            address facet;
            uint32 selectorCount;
            assembly ("memory-safe") {
                facet := shr(96, mload(add(add(packed, 0x20), offset)))
                selectorCount := shr(224, mload(add(add(packed, 0x20), add(offset, 20))))
            }
            offset += 24;

            facets[i] = facet;
            bytes4[] memory facetSelectors = new bytes4[](selectorCount);
            for (uint256 j; j < selectorCount; j++) {
                bytes4 selector;
                assembly ("memory-safe") {
                    selector := mload(add(add(packed, 0x20), offset))
                }
                facetSelectors[j] = selector;
                offset += 4;
            }
            selectors[i] = facetSelectors;
        }
    }
}
