// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

contract ERC20MetadataFacet {
    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
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
     * @notice Returns the ERC20 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC20 storage struct reference.
     */
    function getStorage() internal pure returns (ERC20MetadataStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the name of the token.
     * @return The token name.
     */
    function name() external view returns (string memory) {
        return getStorage().name;
    }

    /**
     * @notice Returns the symbol of the token.
     * @return The token symbol.
     */
    function symbol() external view returns (string memory) {
        return getStorage().symbol;
    }

    /**
     * @notice Returns the number of decimals used for token precision.
     * @return The number of decimals.
     */
    function decimals() external view returns (uint8) {
        return getStorage().decimals;
    }
}
