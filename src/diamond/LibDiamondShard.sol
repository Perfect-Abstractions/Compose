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
    function rebuildDefaultShard() internal {
        DiamondStorage storage ds = getStorage();
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        
        // Only rebuild if sharded loupe is enabled
        if (!sls.enabled) return;

        bytes4[] memory selectors = ds.selectors;
        uint256 selectorCount = selectors.length;
        
        // Count unique facets
        address[] memory tempFacets = new address[](selectorCount);
        uint256 uniqueFacetCount;
        
        for (uint256 i; i < selectorCount; i++) {
            address facet = ds.facetAndPosition[selectors[i]].facet;
            bool found = false;
            for (uint256 j; j < uniqueFacetCount; j++) {
                if (tempFacets[j] == facet) {
                    found = true;
                    break;
                }
            }
            if (!found) {
                tempFacets[uniqueFacetCount] = facet;
                uniqueFacetCount++;
            }
        }
        
        // Create properly sized arrays
        address[] memory facets = new address[](uniqueFacetCount);
        bytes4[][] memory facetSelectors = new bytes4[][](uniqueFacetCount);
        
        for (uint256 i; i < uniqueFacetCount; i++) {
            facets[i] = tempFacets[i];
            
            // Count selectors for this facet
            uint256 count;
            for (uint256 j; j < selectorCount; j++) {
                if (ds.facetAndPosition[selectors[j]].facet == facets[i]) {
                    count++;
                }
            }
            
            // Fill selectors
            facetSelectors[i] = new bytes4[](count);
            uint256 idx;
            for (uint256 j; j < selectorCount; j++) {
                if (ds.facetAndPosition[selectors[j]].facet == facets[i]) {
                    facetSelectors[i][idx] = selectors[j];
                    idx++;
                }
            }
        }
        
        LibShardedLoupe.rebuildShard(DEFAULT_CATEGORY, facets, facetSelectors);
    }

    /// @notice Enable sharded loupe and perform initial build
    function enableShardedLoupe() internal {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        sls.enabled = true;
        rebuildDefaultShard();
    }
}
