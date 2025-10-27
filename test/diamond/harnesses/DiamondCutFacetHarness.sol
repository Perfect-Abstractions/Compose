// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {DiamondCutFacet} from "../../../src/diamond/DiamondCutFacet.sol";

/// @title DiamondCutFacetHarness
/// @notice Test harness for DiamondCutFacet that adds initializaton
contract DiamondCutFacetHarness is DiamondCutFacet {
    /// @notice Initialize DiamondCutFacet owner storage
    /// @dev Only used for testing - production diamonds should initialize in constructor
    /// @param _owner Address of the Facet owner
    function initialize(address _owner) external {
        OwnerStorage storage s = getOwnerStorage();

        s.owner = _owner;
    }
}
