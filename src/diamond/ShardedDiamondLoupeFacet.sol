// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibBlob} from "../libraries/LibBlob.sol";
import {LibShardedLoupe} from "./LibShardedLoupe.sol";

/// @title ShardedDiamondLoupeFacet
/// @notice Optimized Diamond Loupe implementation using sharded SSTORE2 snapshots
/// @dev Falls back to traditional loupe when sharding is not enabled
contract ShardedDiamondLoupeFacet {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    /// @notice Data stored for each function selector
    struct FacetAndPosition {
        address facet;
        uint16 position;
    }

    /// @custom:storage-location erc8042:compose.diamond
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

    /// @notice Struct to hold facet address and its function selectors
    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    /// @notice Gets the facet address that supports the given selector
    /// @param _functionSelector The function selector
    /// @return facet The facet address
    function facetAddress(bytes4 _functionSelector) external view returns (address facet) {
        DiamondStorage storage s = getStorage();
        facet = s.facetAndPosition[_functionSelector].facet;
    }

    /// @notice Gets all the function selectors supported by a specific facet
    /// @param _facet The facet address
    /// @return facetSelectors The function selectors associated with a facet address
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorCount = selectors.length;
        uint256 numSelectors;
        facetSelectors = new bytes4[](selectorCount);
        
        for (uint256 selectorIndex; selectorIndex < selectorCount; selectorIndex++) {
            bytes4 selector = s.selectors[selectorIndex];
            if (_facet == s.facetAndPosition[selector].facet) {
                facetSelectors[numSelectors] = selector;
                numSelectors++;
            }
        }
        
        assembly ("memory-safe") {
            mstore(facetSelectors, numSelectors)
        }
    }

    /// @notice Get all the facet addresses used by a diamond
    /// @return allFacets The facet addresses
    function facetAddresses() external view returns (address[] memory allFacets) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        
        // Use sharded loupe if enabled
        if (sls.enabled && sls.categories.length > 0) {
            return _facetAddressesSharded();
        }
        
        // Fall back to traditional loupe
        return _facetAddressesTraditional();
    }

    /// @notice Get facet addresses using sharded snapshots
    function _facetAddressesSharded() internal view returns (address[] memory allFacets) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        bytes32[] memory cats = sls.categories;
        
        uint256 total;
        for (uint256 i; i < cats.length; i++) {
            total += sls.shards[cats[i]].facetCount;
        }
        
        allFacets = new address[](total);
        uint256 k;
        for (uint256 i; i < cats.length; i++) {
            bytes memory packed = LibBlob.read(sls.shards[cats[i]].facetsBlob);
            k = LibShardedLoupe.unpackAddresses(packed, allFacets, k);
        }
    }

    /// @notice Get facet addresses using traditional method
    function _facetAddressesTraditional() internal view returns (address[] memory allFacets) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        bytes4 selector;
        uint256 selectorsCount = selectors.length;

        allFacets = new address[](selectorsCount);
        address[][256] memory map;
        uint256 key;
        address[] memory bucket;
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            key = uint160(facet) & 0xff;
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                if (bucket[bucketIndex] == facet) {
                    break;
                }
            }
            if (bucketIndex == bucket.length) {
                if (bucketIndex & 3 == 0) {
                    address[] memory newBucket = new address[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
                bucket[bucketIndex] = facet;
                allFacets[numFacets] = facet;
                unchecked {
                    numFacets++;
                }
            }
        }
        assembly ("memory-safe") {
            mstore(allFacets, numFacets)
        }
    }

    /// @notice Gets all facets and their selectors
    /// @return facetsAndSelectors Array of Facet structs
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        
        // Use sharded loupe if enabled
        if (sls.enabled && sls.categories.length > 0) {
            return _facetsSharded();
        }
        
        // Fall back to traditional loupe
        return _facetsTraditional();
    }

    /// @notice Get facets using sharded snapshots
    function _facetsSharded() internal view returns (Facet[] memory facetsAndSelectors) {
        LibShardedLoupe.ShardedLoupeStorage storage sls = LibShardedLoupe.getStorage();
        bytes32[] memory cats = sls.categories;
        
        uint256 total;
        for (uint256 i; i < cats.length; i++) {
            total += sls.shards[cats[i]].facetCount;
        }
        
        facetsAndSelectors = new Facet[](total);
        uint256 k;
        for (uint256 i; i < cats.length; i++) {
            bytes memory packed = LibBlob.read(sls.shards[cats[i]].selectorsBlob);
            k = LibShardedLoupe.unpackAppend(packed, facetsAndSelectors, k);
        }
    }

    /// @notice Get facets using traditional method
    function _facetsTraditional() internal view returns (Facet[] memory facetsAndSelectors) {
        DiamondStorage storage s = getStorage();
        bytes4[] memory selectors = s.selectors;
        uint256 selectorsCount = selectors.length;
        bytes4 selector;

        uint256[] memory facetPointers = new uint256[](selectorsCount);
        uint256 facetPointer;
        Facet memory facetAndSelectors;
        uint256[][256] memory map;
        uint256 key;
        uint256[] memory bucket;
        uint256 numFacets;

        for (uint256 i; i < selectorsCount; i++) {
            selector = selectors[i];
            address facet = s.facetAndPosition[selector].facet;
            key = uint160(facet) & 0xff;
            bucket = map[key];
            uint256 bucketIndex;
            for (; bucketIndex < bucket.length; bucketIndex++) {
                facetPointer = bucket[bucketIndex];
                assembly ("memory-safe") {
                    facetAndSelectors := facetPointer
                }
                if (facetAndSelectors.facet == facet) {
                    bytes4[] memory functionSelectors = facetAndSelectors.functionSelectors;
                    uint256 selectorsLength = functionSelectors.length;
                    if (selectorsLength & 15 == 0) {
                        bytes4[] memory newFunctionSelectors = new bytes4[](selectorsLength + 16);
                        for (uint256 k; k < selectorsLength; k++) {
                            newFunctionSelectors[k] = functionSelectors[k];
                        }
                        functionSelectors = newFunctionSelectors;
                        facetAndSelectors.functionSelectors = functionSelectors;
                    }
                    assembly ("memory-safe") {
                        mstore(functionSelectors, add(selectorsLength, 1))
                    }
                    functionSelectors[selectorsLength] = selector;
                    break;
                }
            }

            if (bucket.length == bucketIndex) {
                if (bucketIndex & 3 == 0) {
                    uint256[] memory newBucket = new uint256[](bucketIndex + 4);
                    for (uint256 k; k < bucketIndex; k++) {
                        newBucket[k] = bucket[k];
                    }
                    bucket = newBucket;
                    map[key] = bucket;
                }
                assembly ("memory-safe") {
                    mstore(bucket, add(bucketIndex, 1))
                }
                bytes4[] memory functionSelectors = new bytes4[](16);
                assembly ("memory-safe") {
                    mstore(functionSelectors, 1)
                }
                functionSelectors[0] = selector;
                facetAndSelectors = Facet({facet: facet, functionSelectors: functionSelectors});
                assembly ("memory-safe") {
                    facetPointer := facetAndSelectors
                }
                bucket[bucketIndex] = facetPointer;
                facetPointers[numFacets] = facetPointer;
                unchecked {
                    numFacets++;
                }
            }
        }

        facetsAndSelectors = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            facetPointer = facetPointers[i];
            assembly ("memory-safe") {
                facetAndSelectors := facetPointer
            }
            facetsAndSelectors[i].facet = facetAndSelectors.facet;
            facetsAndSelectors[i].functionSelectors = facetAndSelectors.functionSelectors;
        }
    }
}
