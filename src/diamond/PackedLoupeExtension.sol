// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibBlob} from "../libraries/LibBlob.sol";
import {LibShardedLoupe} from "./LibShardedLoupe.sol";

/// @title PackedLoupeExtension
/// @notice Extension providing packed/compressed loupe functions for minimal return data
/// @dev Can be added alongside standard loupe for power users who want minimal bytes
contract PackedLoupeExtension {
    bytes32 constant SHARDED_LOUPE_STORAGE_POSITION = keccak256("compose.sharded.loupe");

    struct Shard {
        address facetsBlob;
        address selectorsBlob;
        uint32 facetCount;
        uint32 selectorCount;
    }

    struct ShardedLoupeStorage {
        mapping(bytes32 categoryId => Shard) shards;
        bytes32[] categories;
        bool enabled;
    }

    function getStorage() internal pure returns (ShardedLoupeStorage storage s) {
        bytes32 position = SHARDED_LOUPE_STORAGE_POSITION;
        assembly ("memory-safe") {
            s.slot := position
        }
    }

    /// @notice Get facet addresses as packed bytes
    /// @dev Returns abi.encodePacked(f0, f1, f2, ...) - 20 bytes per facet
    /// @return packed Tightly packed facet addresses
    function facetAddressesPacked() external view returns (bytes memory packed) {
        ShardedLoupeStorage storage sls = getStorage();
        
        if (!sls.enabled || sls.categories.length == 0) {
            return packed;
        }
        
        bytes32[] memory cats = sls.categories;
        
        // Read all blobs and concatenate
        for (uint256 i; i < cats.length; i++) {
            bytes memory blob = LibBlob.read(sls.shards[cats[i]].facetsBlob);
            // Skip the count prefix (first 4 bytes) and just get addresses
            if (blob.length > 4) {
                bytes memory addresses;
                assembly ("memory-safe") {
                    let len := sub(mload(blob), 4)
                    addresses := mload(0x40)
                    mstore(addresses, len)
                    let src := add(blob, 0x24) // skip length word + 4 byte count
                    let dst := add(addresses, 0x20)
                    for { let j := 0 } lt(j, len) { j := add(j, 0x20) } {
                        mstore(add(dst, j), mload(add(src, j)))
                    }
                    mstore(0x40, add(addresses, add(0x20, len)))
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
        ShardedLoupeStorage storage sls = getStorage();
        
        if (!sls.enabled || sls.categories.length == 0) {
            return packed;
        }
        
        bytes32[] memory cats = sls.categories;
        
        for (uint256 i; i < cats.length; i++) {
            bytes memory blob = LibBlob.read(sls.shards[cats[i]].selectorsBlob);
            (address[] memory facets, bytes4[][] memory selectors) = 
                LibShardedLoupe.unpackFacetsAndSelectors(blob);
            
            for (uint256 j; j < facets.length; j++) {
                if (facets[j] == _facet) {
                    for (uint256 k; k < selectors[j].length; k++) {
                        packed = bytes.concat(packed, selectors[j][k]);
                    }
                }
            }
        }
    }

    /// @notice Get all facets with selectors in RLE format
    /// @dev Format: [addr | count | 4b*count]... for each facet
    /// @return packed RLE-compressed facet and selector data
    function facetsPacked() external view returns (bytes memory packed) {
        ShardedLoupeStorage storage sls = getStorage();
        
        if (!sls.enabled || sls.categories.length == 0) {
            return packed;
        }
        
        bytes32[] memory cats = sls.categories;
        
        for (uint256 i; i < cats.length; i++) {
            bytes memory blob = LibBlob.read(sls.shards[cats[i]].selectorsBlob);
            (address[] memory facets, bytes4[][] memory selectors) = 
                LibShardedLoupe.unpackFacetsAndSelectors(blob);
            
            for (uint256 j; j < facets.length; j++) {
                // Append: facet address (20 bytes)
                packed = bytes.concat(packed, abi.encodePacked(facets[j]));
                // Append: selector count (4 bytes)
                packed = bytes.concat(packed, abi.encodePacked(uint32(selectors[j].length)));
                // Append: selectors (4 bytes each)
                for (uint256 k; k < selectors[j].length; k++) {
                    packed = bytes.concat(packed, abi.encodePacked(selectors[j][k]));
                }
            }
        }
    }
}
