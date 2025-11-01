// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {DiamondCutFacet} from "../../../src/diamond/DiamondCutFacet.sol";

/// @title DiamondCutFacetHarness
/// @notice Test harness for DiamondCutFacet that adds initializaton
contract DiamondCutFacetHarness is DiamondCutFacet {
    error FunctionNotFound(bytes4 selector);

    /// @notice Initialize DiamondCutFacet owner storage
    /// @dev Only used for testing - production diamonds should initialize in constructor
    /// @param _owner Address of the Facet owner
    function initialize(address _owner) external {
        OwnerStorage storage s = getOwnerStorage();

        s.owner = _owner;
    }

    fallback() external payable {
        DiamondStorage storage s = getDiamondStorage();
        address facet = s.facetAndPosition[msg.sig].facet;
        if (facet == address(0)) revert FunctionNotFound(msg.sig);

        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), facet, 0, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(0, 0, size)
            switch result
            case 0 { revert(0, size) }
            default { return(0, size) }
        }
    }

    receive() external payable {}
}
