// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {OwnerFacet} from "../../../../src/access/Owner/OwnerFacet.sol";

/// @title OwnerFacet Test Harness
/// @notice Extends OwnerFacet with initialization and test-specific functions
contract OwnerFacetHarness is OwnerFacet {
    /// @notice Initialize the owner for testing
    /// @dev This function is only for testing purposes
    function initialize(address _owner) external {
        OwnerStorage storage s = getStorage();
        s.owner = _owner;
    }

    /// @notice Force set owner without any checks (for testing edge cases)
    /// @dev This bypasses all access control for testing purposes
    function forceSetOwner(address _owner) external {
        OwnerStorage storage s = getStorage();
        s.owner = _owner;
    }

    /// @notice Get the raw storage owner value (for testing storage consistency)
    function getStorageOwner() external view returns (address) {
        return getStorage().owner;
    }
}
