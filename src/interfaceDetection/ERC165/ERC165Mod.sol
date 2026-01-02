// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title LibERC165 — ERC-165 Standard Interface Detection Library
 * @notice Provides internal functions and storage layout for ERC-165 interface detection.
 * @dev Uses ERC-8042 for storage location standardization
 */

/*
 * Storage slot identifier, defined using keccak256 hash of the library diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.erc165");

/*
 * @notice ERC-165 storage layout using the ERC-8042 standard.
 * @custom:storage-location erc8042:compose.erc165
 */
struct ERC165Storage {
    /*
     * @notice Mapping of interface IDs to whether they are supported
     */
    mapping(bytes4 => bool) supportedInterfaces;
}

/**
 * @notice Returns a pointer to the ERC-165 storage struct.
 * @dev Uses inline assembly to bind the storage struct to the fixed storage position.
 * @return s The ERC-165 storage struct.
 */
function getStorage() pure returns (ERC165Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Register that a contract supports an interface
 * @param _interfaceId The interface ID to register
 * @dev Call this function during initialization to register supported interfaces.
 * For example, in an ERC721 facet initialization, you would call:
 * `LibERC165.registerInterface(type(IERC721).interfaceId)`
 */
function registerInterface(bytes4 _interfaceId) {
    ERC165Storage storage s = getStorage();
    s.supportedInterfaces[_interfaceId] = true;
}
