// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title  LibERC20Metadata — Library for ERC-20 Optional Metadata Library
 * @notice Provides internal functions and storage layout for ERC-20 Optional Metadata token logic.
 * @dev    Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions.
 */

/*
 * @notice Storage slot identifier, defined using keccak256 hash of the library diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("compose.erc20.metadata");

/**
 * @dev ERC-8042 compliant storage struct for ERC20 token data.
 * @custom:storage-location erc8042:compose.erc20.metadata
 */
struct ERC20MetadataStorage {
    string name;
    string symbol;
    uint8 decimals;
}

/**
 * @notice Returns a pointer to the ERC-20 storage struct.
 * @dev Uses inline assembly to bind the storage struct to the fixed storage position.
 * @return s The ERC-20 storage struct.
 */
function getStorage() pure returns (ERC20MetadataStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

function setMetadata(
    string memory _name,
    string memory _symbol,
    uint8 memory _decimals
) {
    ERC20MetadataStorage storage s = getStorage();
    s.name = _name;
    s.symbol = _symbol;
    s.decimals = _decimals;
}
