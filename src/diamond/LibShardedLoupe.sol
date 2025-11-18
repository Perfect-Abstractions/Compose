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
        uint32 facetCount;
    }

    /// @custom:storage-location erc8042:compose.sharded.loupe
    struct ShardedLoupeStorage {
        mapping(bytes32 categoryId => Shard) shards;
        bytes32[] categories;
        mapping(bytes32 categoryId => bool) categoryExists; // Track category existence
        bool enabled; // Flag to enable/disable sharded loupe
        mapping(address facet => uint256 indexPlusOne) facetIndex; // Scratch space for rebuilds
        address[] facetIndexList; // Scratch keys list to clean up facetIndex mapping
        mapping(address facet => address) facetSelectorsBlob; // Pointer to packed selectors per facet
        mapping(address facet => uint32) facetSelectorCount; // Selector count per facet
        mapping(address facet => bytes32) facetCategory; // Category assignment for cleanup
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

        Shard storage shard = s.shards[categoryId];

        // Mark current facets for quick membership checks
        for (uint256 i; i < facets.length; i++) {
            s.facetIndex[facets[i]] = 1;
        }

        // Clean up selectors for facets no longer in this category
        if (shard.facetsBlob != address(0) && shard.facetCount != 0) {
            bytes memory previousPacked = LibBlob.read(shard.facetsBlob);
            uint256 prevOffset = 4;
            for (uint256 i; i < shard.facetCount; i++) {
                address oldFacet;
                assembly ("memory-safe") {
                    oldFacet := shr(96, mload(add(add(previousPacked, 0x20), prevOffset)))
                }
                prevOffset += 20;

                if (s.facetIndex[oldFacet] == 0) {
                    s.facetSelectorsBlob[oldFacet] = address(0);
                    s.facetSelectorCount[oldFacet] = 0;
                    s.facetCategory[oldFacet] = bytes32(0);
                }
            }
        }

        uint256 facetCount = facets.length;

        // Pack facet addresses with single allocation to avoid quadratic memory usage
        bytes memory packedFacets = new bytes(4 + facetCount * 20);
        assembly ("memory-safe") {
            mstore(add(packedFacets, 0x20), shl(224, facetCount))
        }

        uint256 offset = 4;
        for (uint256 i; i < facetCount; i++) {
            address facet = facets[i];
            assembly ("memory-safe") {
                mstore(add(add(packedFacets, 0x20), offset), shl(96, facet))
            }
            offset += 20;
        }
        address facetsBlob = LibBlob.write(packedFacets);

        // Store the shard
        shard.facetsBlob = facetsBlob;
        shard.facetCount = uint32(facets.length);

        // Store per-facet selector blobs
        for (uint256 i; i < facetCount; i++) {
            _storeFacetSelectors(s, facets[i], selectors[i], categoryId);
        }

        // Clear temporary facet index marks
        for (uint256 i; i < facets.length; i++) {
            s.facetIndex[facets[i]] = 0;
        }

        // Add category if not already present - O(1) lookup
        if (!s.categoryExists[categoryId]) {
            s.categories.push(categoryId);
            s.categoryExists[categoryId] = true;
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

    /// @notice Return selectors for a facet using sharded snapshots (empty if missing)
    function getFacetSelectors(address facet) internal view returns (bytes4[] memory selectors) {
        ShardedLoupeStorage storage s = getStorage();
        uint256 selectorCount = s.facetSelectorCount[facet];
        selectors = new bytes4[](selectorCount);
        if (selectorCount == 0) {
            return selectors;
        }

        address blob = s.facetSelectorsBlob[facet];
        if (blob == address(0)) {
            assembly ("memory-safe") {
                mstore(selectors, 0)
            }
            return selectors;
        }

        bytes memory packed = LibBlob.read(blob);
        uint256 offset = 4;
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector;
            assembly ("memory-safe") {
                selector := mload(add(add(packed, 0x20), offset))
            }
            selectors[i] = selector;
            offset += 4;
        }
    }

    /// @notice Return packed selectors payload for a facet (excluding the count prefix)
    function getFacetSelectorsPacked(address facet) internal view returns (bytes memory packedSelectors) {
        ShardedLoupeStorage storage s = getStorage();
        address blob = s.facetSelectorsBlob[facet];
        if (blob == address(0)) {
            return packedSelectors;
        }
        bytes memory data = LibBlob.read(blob);
        if (data.length <= 4) {
            return packedSelectors;
        }
        uint256 payloadLength = data.length - 4;
        packedSelectors = new bytes(payloadLength);
        assembly ("memory-safe") {
            let src := add(data, 0x24)
            let dst := add(packedSelectors, 0x20)
            for { let i := 0 } lt(i, payloadLength) { i := add(i, 0x20) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }
    }

    function _storeFacetSelectors(
        ShardedLoupeStorage storage s,
        address facet,
        bytes4[] memory facetSelectors,
        bytes32 categoryId
    ) internal {
        uint256 selsLength = facetSelectors.length;
        bytes memory packedSelectors = new bytes(4 + selsLength * 4);
        assembly ("memory-safe") {
            mstore(add(packedSelectors, 0x20), shl(224, selsLength))
        }

        uint256 selectorOffset = 4;
        for (uint256 j; j < selsLength; j++) {
            bytes4 selector = facetSelectors[j];
            assembly ("memory-safe") {
                mstore(add(add(packedSelectors, 0x20), selectorOffset), selector)
            }
            selectorOffset += 4;
        }

        bytes32 newHash = keccak256(packedSelectors);
        address selectorsBlob = s.facetSelectorsBlob[facet];
        if (selectorsBlob != address(0)) {
            uint256 existingSize;
            assembly ("memory-safe") {
                existingSize := extcodesize(selectorsBlob)
            }
            if (existingSize == packedSelectors.length) {
                bytes memory existing = LibBlob.read(selectorsBlob);
                if (keccak256(existing) != newHash) {
                    selectorsBlob = address(0);
                }
            } else {
                selectorsBlob = address(0);
            }
        }

        if (selectorsBlob == address(0)) {
            selectorsBlob = LibBlob.write(packedSelectors);
        }

        s.facetSelectorsBlob[facet] = selectorsBlob;
        s.facetSelectorCount[facet] = uint32(selsLength);
        s.facetCategory[facet] = categoryId;
    }
}
