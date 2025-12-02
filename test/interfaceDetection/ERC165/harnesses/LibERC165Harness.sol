// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/interfaceDetection/ERC165/LibERC165.sol" as LibERC165;

/// @title LibERC165 Test Harness
/// @notice Exposes internal LibERC165 functions as external for testing
contract LibERC165Harness {
    /// @notice Initialize the ERC165 storage (for testing)
    function initialize() external {
        // No initialization needed for basic ERC165
        // Storage is automatically available
    }

    /// @notice Register an interface
    function registerInterface(bytes4 _interfaceId) external {
        LibERC165.registerInterface(_interfaceId);
    }

    /// @notice Check if an interface is supported
    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        LibERC165.ERC165Storage storage s = LibERC165.getStorage();
        return s.supportedInterfaces[_interfaceId];
    }

    /// @notice Get storage directly (for testing storage consistency)
    function getStorageValue(bytes4 _interfaceId) external view returns (bool) {
        return LibERC165.getStorage().supportedInterfaces[_interfaceId];
    }

    /// @notice Get the storage position
    function getStoragePosition() external pure returns (bytes32) {
        return keccak256("compose.erc165");
    }

    /// @notice Force set an interface support value (for testing edge cases)
    function forceSetInterface(bytes4 _interfaceId, bool _supported) external {
        LibERC165.ERC165Storage storage s = LibERC165.getStorage();
        s.supportedInterfaces[_interfaceId] = _supported;
    }

    /// @notice Register multiple interfaces at once (for testing)
    function registerMultipleInterfaces(bytes4[] calldata _interfaceIds) external {
        for (uint256 i = 0; i < _interfaceIds.length; i++) {
            LibERC165.registerInterface(_interfaceIds[i]);
        }
    }
}
