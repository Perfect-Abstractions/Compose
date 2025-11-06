// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibShardedLoupe} from "./LibShardedLoupe.sol";

/// @title LibDiamondShard
/// @notice Helper library for managing sharded loupe updates during diamond cuts
library LibDiamondShard {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");
    bytes32 constant DEFAULT_CATEGORY = keccak256("loupe:category:default");

    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
    }

    function getStorage() internal pure returns (DiamondStorage storage s) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly ("memory-safe") {
            s.slot := position
        }
    }

    /// @notice Rebuild the default shard with current diamond state
    /// @dev Should be called after any diamond cut operation
    /// @dev Uses O(n²) for finding unique facets, but this only runs during cuts (rare operation)
    function rebuildDefaultShard() internal {
        DiamondStorage storage ds = getStorage();
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        
        // Only rebuild if sharded loupe is enabled
        if (!sls.enabled) return;

        bytes4[] memory selectors = ds.selectors;
        uint256 selectorCount = selectors.length;

        if (selectorCount == 0) {
            LibShardedLoupe.rebuildShard(DEFAULT_CATEGORY, new address[](0), new bytes4[][](0));
            return;
        }

        uint256[] memory counts = new uint256[](selectorCount);
        uint256 uniqueFacetCount;

        // First pass: count selectors per facet while tracking unique facets via storage-backed scratchpad
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = selectors[i];
            address facet = ds.facetAndPosition[selector].facet;
            uint256 index = sls.facetIndex[facet];
            if (index == 0) {
                uniqueFacetCount++;
                sls.facetIndex[facet] = uniqueFacetCount;
                sls.facetIndexList.push(facet);
                index = uniqueFacetCount;
            }
            counts[index - 1]++;
        }

        address[] memory facets = new address[](uniqueFacetCount);
        bytes4[][] memory facetSelectors = new bytes4[][](uniqueFacetCount);
        uint256[] memory writePositions = new uint256[](uniqueFacetCount);

        for (uint256 i; i < uniqueFacetCount; i++) {
            address facetAddr = sls.facetIndexList[i];
            facets[i] = facetAddr;
            facetSelectors[i] = new bytes4[](counts[i]);
        }

        // Second pass: populate selector arrays per facet
        for (uint256 i; i < selectorCount; i++) {
            bytes4 selector = selectors[i];
            address facet = ds.facetAndPosition[selector].facet;
            uint256 index = sls.facetIndex[facet] - 1;
            uint256 writeIndex = writePositions[index];
            facetSelectors[index][writeIndex] = selector;
            writePositions[index] = writeIndex + 1;
        }

        LibShardedLoupe.rebuildShard(DEFAULT_CATEGORY, facets, facetSelectors);

        // Clean up scratch space to avoid stale indexes on subsequent rebuilds
        for (uint256 i; i < uniqueFacetCount; i++) {
            address facetAddr = sls.facetIndexList[sls.facetIndexList.length - 1];
            sls.facetIndex[facetAddr] = 0;
            sls.facetIndexList.pop();
        }
    }

    /// @notice Enable sharded loupe and perform initial build
    function enableShardedLoupe() internal {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        sls.enabled = true;
        rebuildDefaultShard();
    }
}
