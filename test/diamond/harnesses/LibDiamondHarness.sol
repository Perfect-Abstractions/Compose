// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibDiamond} from "../../../src/diamond/LibDiamond.sol";

/// @title LibDiamondHarness
/// @notice Test harness that exposes LibDiamond's internal functions as external
/// @dev Required for testing since LibDiamond only has internal functions
contract LibDiamondHarness {
    function addFunctions(address _facet, bytes4[] calldata _functionSelectors) external {
        LibDiamond.addFunctions(_facet, _functionSelectors);
    }

    function replaceFunctions(address _facet, bytes4[] calldata _functionSelectors) external {
        LibDiamond.replaceFunctions(_facet, _functionSelectors);
    }

    function removeFunctions(address _facet, bytes4[] calldata _functionSelectos) external {
        LibDiamond.removeFunctions(_facet, _functionSelectos);
    }

    function diamondCut(LibDiamond.FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external {
        LibDiamond.diamondCut(_diamondCut, _init, _calldata);
    }

    /// @notice Read the facet and its selector position for a given function selector
    function getFacetAndPosition(bytes4 selector) external view returns (address facet, uint16 position) {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        LibDiamond.FacetAndPosition memory f = s.facetAndPosition[selector];
        return (f.facet, f.position);
    }

    /// @notice Return the full list of registered selectors
    function getSelectors() external view returns (bytes4[] memory) {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        return s.selectors;
    }

    /// @notice Convenience: number of selectors registered
    function getSelectorsLength() external view returns (uint256) {
        LibDiamond.DiamondStorage storage s = LibDiamond.getStorage();
        return s.selectors.length;
    }
}
