// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("erc20.metadata");

/**
 * @dev ERC-8042 compliant storage struct for ERC20 token data.
 * @custom:storage-location erc8042:erc20.metadata
 */
struct ERC20MetadataStorage {
    string name;
    string symbol;
    uint8 decimals;
}

/**
 * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
 * @dev Uses inline assembly to set the storage slot reference.
 * @return s The ERC20 storage struct reference.
 */
function getStorage() pure returns (ERC20MetadataStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Sets the metadata for the ERC20 token.
 * @param _name The name of the token.
 * @param _symbol The symbol of the token.
 * @param _decimals The number of decimals used for token precision.
 */
function setMetadata(string memory _name, string memory _symbol, uint8 _decimals) {
    ERC20MetadataStorage storage s = getStorage();
    s.name = _name;
    s.symbol = _symbol;
    s.decimals = _decimals;
}

