// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../src/diamond/DiamondCut.sol" as DiamondCut;

/**
 * @title DiamondHarness
 * @notice Test harness that exposes LibDiamond's internal functions as external
 * @dev Required for testing since LibDiamond only has internal functions
 */
contract DiamondHarness {
    function addFunctions(address _facet, bytes4[] calldata _functionSelectors) external {
        DiamondCut.addFunctions(_facet, _functionSelectors);
    }

    function replaceFunctions(address _facet, bytes4[] calldata _functionSelectors) external {
        DiamondCut.replaceFunctions(_facet, _functionSelectors);
    }

    function removeFunctions(address _facet, bytes4[] calldata _functionSelectos) external {
        DiamondCut.removeFunctions(_facet, _functionSelectos);
    }

    function diamondCut(DiamondCut.FacetCut[] calldata _diamondCut, address _init, bytes calldata _calldata) external {
        DiamondCut.diamondCut(_diamondCut, _init, _calldata);
    }

    /**
     * @notice Read the facet and its selector position for a given function selector
     */
    function getFacetAndPosition(bytes4 selector) external view returns (address facet, uint32 position) {
        DiamondCut.DiamondStorage storage s = DiamondCut.getStorage();
        DiamondCut.FacetAndPosition memory f = s.facetAndPosition[selector];
        return (f.facet, f.position);
    }

    /**
     * @notice Return the full list of registered selectors
     */
    function getSelectors() external view returns (bytes4[] memory) {
        DiamondCut.DiamondStorage storage s = DiamondCut.getStorage();
        return s.selectors;
    }

    /**
     * @notice Convenience: number of selectors registered
     */
    function getSelectorsLength() external view returns (uint256) {
        DiamondCut.DiamondStorage storage s = DiamondCut.getStorage();
        return s.selectors.length;
    }
}
