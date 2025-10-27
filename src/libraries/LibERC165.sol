// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";

/// @title LibERC165 — ERC-165 Standard Interface Detection Library
/// @notice Provides internal functions and storage layout for ERC-165 interface detection.
/// @dev Uses ERC-8042 for storage location standardization
library LibERC165 {
    /// @notice Storage slot identifier, defined using keccak256 hash of the library diamond storage identifier.
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc165");

    /// @notice ERC-165 storage layout using the ERC-8042 standard.
    /// @custom:storage-location erc8042:compose.erc165
    struct ERC165Storage {
        /// @notice Mapping of interface IDs to whether they are supported
        mapping(bytes4 => bool) supportedInterfaces;
    }

    /// @notice Returns a pointer to the ERC-165 storage struct.
    /// @dev Uses inline assembly to bind the storage struct to the fixed storage position.
    /// @return s The ERC-165 storage struct.
    function getStorage() internal pure returns (ERC165Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Register that a contract supports an interface
    /// @param _interfaceId The interface ID to register
    /// @dev Call this function during initialization to register supported interfaces.
    /// For example, in an ERC721 facet initialization, you would call:
    /// `LibERC165.registerInterface(type(IERC721).interfaceId)`
    function registerInterface(bytes4 _interfaceId) internal {
        ERC165Storage storage s = getStorage();
        s.supportedInterfaces[_interfaceId] = true;
    }

    /// @notice Check if a contract supports an interface
    /// @param _interfaceId The interface ID to check
    /// @return True if the interface is supported, false otherwise
    function supportsInterface(bytes4 _interfaceId) internal view returns (bool) {
        ERC165Storage storage s = getStorage();
        // If the ERC165 interface itself is being queried, return true
        // since this library implements ERC165
        if (_interfaceId == type(IERC165).interfaceId) {
            return true;
        }
        return s.supportedInterfaces[_interfaceId];
    }
}
