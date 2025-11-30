// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {ERC165Facet} from "../../../../src/interfaceDetection/ERC165/ERC165Facet.sol";

/// @title ERC165Facet Test Harness
/// @notice Extends ERC165Facet with initialization and test-specific functions
contract ERC165FacetHarness is ERC165Facet {
    /// @notice Initialize the ERC165 storage for testing
    /// @dev This function is only for testing purposes
    function initialize() external {
        // No initialization needed for basic ERC165
        // Storage is automatically available
    }

    /// @notice Register an interface for testing
    /// @dev Exposes internal storage manipulation for testing
    function registerInterface(bytes4 _interfaceId) external {
        ERC165Storage storage s = getStorage();
        s.supportedInterfaces[_interfaceId] = true;
    }

    /// @notice Unregister an interface for testing
    /// @dev Exposes internal storage manipulation for testing
    function unregisterInterface(bytes4 _interfaceId) external {
        ERC165Storage storage s = getStorage();
        s.supportedInterfaces[_interfaceId] = false;
    }

    /// @notice Get the raw storage value for an interface (for testing storage consistency)
    function getStorageValue(bytes4 _interfaceId) external view returns (bool) {
        return getStorage().supportedInterfaces[_interfaceId];
    }

    /// @notice Expose getStorage for testing
    function exposedGetStorage() external pure returns (bytes32) {
        return STORAGE_POSITION;
    }
}
