// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title IsolatedShardedLoupe
/// @notice EXPERIMENTAL - Isolated sharded loupe with namespaced storage
/// @dev This is an optional, standalone implementation that doesn't rely on shared diamond storage
/// @dev Can be used independently or swapped out without affecting the main build
/// @dev Following the pattern from issue #162 - isolated storage reduces gas and conflicts
contract IsolatedShardedLoupe {
    // Isolated storage - completely separate from diamond storage
    bytes32 private constant ISOLATED_LOUPE_SLOT = keccak256("isolated.sharded.loupe.v1");

    struct IsolatedShard {
        address facetsBlob;
        address selectorsBlob;
        uint32 facetCount;
        uint32 selectorCount;
    }

    struct IsolatedStorage {
        mapping(bytes32 categoryId => IsolatedShard) shards;
        bytes32[] categories;
        mapping(bytes4 selector => address) selectorToFacet;
        mapping(address facet => bytes4[]) facetToSelectors;
        address[] allFacets;
    }

    function _getIsolatedStorage() private pure returns (IsolatedStorage storage s) {
        bytes32 slot = ISOLATED_LOUPE_SLOT;
        assembly ("memory-safe") {
            s.slot := slot
        }
    }

    struct Facet {
        address facet;
        bytes4[] functionSelectors;
    }

    /// @notice Get facet for a selector (isolated implementation)
    /// @param selector The function selector
    /// @return facet The facet address
    function facetAddress(bytes4 selector) external view returns (address facet) {
        IsolatedStorage storage s = _getIsolatedStorage();
        return s.selectorToFacet[selector];
    }

    /// @notice Get selectors for a facet (isolated implementation)
    /// @param _facet The facet address
    /// @return selectors The function selectors
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory selectors) {
        IsolatedStorage storage s = _getIsolatedStorage();
        return s.facetToSelectors[_facet];
    }

    /// @notice Get all facet addresses (isolated implementation)
    /// @return facets All facet addresses
    function facetAddresses() external view returns (address[] memory facets) {
        IsolatedStorage storage s = _getIsolatedStorage();
        return s.allFacets;
    }

    /// @notice Get all facets with their selectors (isolated implementation)
    /// @return facetsAndSelectors Array of Facet structs
    function facets() external view returns (Facet[] memory facetsAndSelectors) {
        IsolatedStorage storage s = _getIsolatedStorage();
        address[] memory allFacets = s.allFacets;
        facetsAndSelectors = new Facet[](allFacets.length);

        for (uint256 i; i < allFacets.length; i++) {
            facetsAndSelectors[i] = Facet({facet: allFacets[i], functionSelectors: s.facetToSelectors[allFacets[i]]});
        }
    }

    /// @notice Admin function to sync from diamond storage (if integrated)
    /// @dev This would be called after diamond cuts to update the isolated storage
    function _syncFromDiamond(address[] memory facets, bytes4[][] memory selectors) internal {
        IsolatedStorage storage s = _getIsolatedStorage();

        // Clear old data
        for (uint256 i; i < s.allFacets.length; i++) {
            delete s.facetToSelectors[s.allFacets[i]];
        }
        delete s.allFacets;

        // Store new data
        s.allFacets = facets;
        for (uint256 i; i < facets.length; i++) {
            s.facetToSelectors[facets[i]] = selectors[i];
            for (uint256 j; j < selectors[i].length; j++) {
                s.selectorToFacet[selectors[i][j]] = facets[i];
            }
        }
    }
}
