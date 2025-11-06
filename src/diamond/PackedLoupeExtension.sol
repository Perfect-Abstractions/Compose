// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibBlob} from "../libraries/LibBlob.sol";
import {LibShardedLoupe} from "./LibShardedLoupe.sol";

/// @title PackedLoupeExtension
/// @notice Extension providing packed/compressed loupe functions for minimal return data
/// @dev Can be added alongside standard loupe for power users who want minimal bytes
contract PackedLoupeExtension {
    /// @notice Get facet addresses as packed bytes
    /// @dev Returns abi.encodePacked(f0, f1, f2, ...) - 20 bytes per facet
    /// @return packed Tightly packed facet addresses
    function facetAddressesPacked() external view returns (bytes memory packed) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        
        if (!sls.enabled || sls.categories.length == 0) {
            return packed;
        }
        
        bytes32[] memory cats = sls.categories;
        
        // Read all blobs and concatenate
        for (uint256 i; i < cats.length; i++) {
            LibShardedLoupe.Shard storage shard = sls.shards[cats[i]];
            bytes memory blob = LibBlob.read(shard.facetsBlob);
            if (blob.length > 4) {
                uint256 len = blob.length - 4;
                bytes memory addresses = new bytes(len);
                assembly ("memory-safe") {
                    let src := add(blob, 0x24)
                    let dst := add(addresses, 0x20)
                    for { let j := 0 } lt(j, len) { j := add(j, 0x20) } {
                        mstore(add(dst, j), mload(add(src, j)))
                    }
                }
                packed = bytes.concat(packed, addresses);
            }
        }
    }

    /// @notice Get selectors for a facet as packed bytes
    /// @dev Returns raw 4-byte selector concatenation
    /// @param _facet The facet address
    /// @return packed Tightly packed 4-byte selectors
    function selectorsPacked(address _facet) external view returns (bytes memory packed) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        if (!sls.enabled || sls.categories.length == 0) {
            return packed;
        }
        return LibShardedLoupe.getFacetSelectorsPacked(_facet);
    }

    /// @notice Get all facets with selectors in RLE format
    /// @dev Format: [addr | count | 4b*count]... for each facet
    /// @return packed RLE-compressed facet and selector data
    function facetsPacked() external view returns (bytes memory packed) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        
        if (!sls.enabled || sls.categories.length == 0) {
            return packed;
        }
        
        bytes32[] memory cats = sls.categories;
        
        for (uint256 i; i < cats.length; i++) {
            LibShardedLoupe.Shard storage shard = sls.shards[cats[i]];
            bytes memory blob = LibBlob.read(shard.facetsBlob);
            if (shard.facetCount == 0 || blob.length < 4) {
                continue;
            }

            address[] memory categoryFacets = new address[](shard.facetCount);
            LibShardedLoupe.unpackAddresses(blob, categoryFacets, 0);

            for (uint256 j; j < categoryFacets.length; j++) {
                address facet = categoryFacets[j];
                uint32 selectorCount = sls.facetSelectorCount[facet];
                packed = bytes.concat(packed, abi.encodePacked(facet));
                packed = bytes.concat(packed, abi.encodePacked(selectorCount));
                if (selectorCount > 0) {
                    packed = bytes.concat(packed, LibShardedLoupe.getFacetSelectorsPacked(facet));
                }
            }
        }
    }
}
