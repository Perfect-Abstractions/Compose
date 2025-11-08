// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title Dawid919 Diamond Loupe Facet Implementation
/// @notice Mirrors @Dawid919's high-level loupe interface using Compose's diamond storage layout
contract Dawid919DiamondLoupeFacet {
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
        address facetAddress;
        bytes4[] functionSelectors;
    }

    function _diamondStorage() internal pure returns (DiamondStorage storage ds) {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }

    function facetAddress(bytes4 functionSelector) external view returns (address facetAddress_) {
        DiamondStorage storage ds = _diamondStorage();
        facetAddress_ = ds.facetAndPosition[functionSelector].facet;
    }

    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        DiamondStorage storage ds = _diamondStorage();
        bytes4[] memory selectors = ds.selectors;
        uint256 totalSelectors = selectors.length;
        if (totalSelectors == 0) return new address[](0);

        address[] memory buffer = new address[](totalSelectors);
        uint256 count;

        for (uint256 i; i < totalSelectors; i++) {
            address facet = ds.facetAndPosition[selectors[i]].facet;
            bool seen;
            for (uint256 j; j < count; j++) {
                if (buffer[j] == facet) {
                    seen = true;
                    break;
                }
            }
            if (!seen) {
                buffer[count] = facet;
                unchecked {
                    ++count;
                }
            }
        }

        facetAddresses_ = new address[](count);
        for (uint256 i; i < count; i++) {
            facetAddresses_[i] = buffer[i];
        }
    }

    function facetFunctionSelectors(address facet) external view returns (bytes4[] memory facetFunctionSelectors_) {
        DiamondStorage storage ds = _diamondStorage();
        bytes4[] memory selectors = ds.selectors;
        uint256 totalSelectors = selectors.length;
        if (totalSelectors == 0) return new bytes4[](0);

        uint256 count;
        for (uint256 i; i < totalSelectors; i++) {
            if (ds.facetAndPosition[selectors[i]].facet == facet) {
                unchecked {
                    ++count;
                }
            }
        }

        facetFunctionSelectors_ = new bytes4[](count);
        if (count == 0) return facetFunctionSelectors_;

        uint256 cursor;
        for (uint256 i; i < totalSelectors; i++) {
            bytes4 selector = selectors[i];
            if (ds.facetAndPosition[selector].facet == facet) {
                facetFunctionSelectors_[cursor] = selector;
                unchecked {
                    ++cursor;
                }
            }
        }
    }

    function facets() external view returns (Facet[] memory facets_) {
        address[] memory uniqueFacets = this.facetAddresses();
        uint256 numFacets = uniqueFacets.length;
        facets_ = new Facet[](numFacets);

        for (uint256 i; i < numFacets; i++) {
            address facet = uniqueFacets[i];
            bytes4[] memory selectors = this.facetFunctionSelectors(facet);
            facets_[i] = Facet({facetAddress: facet, functionSelectors: selectors});
        }
    }
}

