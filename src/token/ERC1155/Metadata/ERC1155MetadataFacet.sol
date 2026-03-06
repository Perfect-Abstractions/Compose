// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Metadata Facet
 * @notice Provides URI metadata functionality for ERC-1155 tokens.
 */
contract ERC1155MetadataFacet {
    /**
     * @notice Emitted when the URI for token type `_id` changes to `_value`.
     * @param _value The new URI for the token type.
     * @param _id The token type whose URI changed.
     */
    event URI(string _value, uint256 indexed _id);

    /**
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("erc1155.metadata");

    /**
     * @dev ERC-8042 compliant storage struct for ERC-1155 metadata.
     * @custom:storage-location erc8042:erc1155.metadata
     */
    struct ERC1155MetadataStorage {
        string uri;
        string baseURI;
        mapping(uint256 tokenId => string) tokenURIs;
    }

    /**
     * @notice Returns the ERC-1155 metadata storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC-1155 metadata storage struct reference.
     */
    function getStorage() internal pure returns (ERC1155MetadataStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the URI for token type `_id`.
     * @dev If a token-specific URI is set in tokenURIs[_id], returns the concatenation of baseURI and tokenURIs[_id].
     *      Note that baseURI is empty by default and must be set explicitly if concatenation is desired.
     *      If no token-specific URI is set, returns the default URI which applies to all token types.
     *      The default URI may contain the substring `{id}` which clients should replace with the actual token ID.
     * @param _id The token ID to query.
     * @return The URI for the token type.
     */
    function uri(uint256 _id) external view returns (string memory) {
        ERC1155MetadataStorage storage s = getStorage();
        string memory tokenURI = s.tokenURIs[_id];

        return bytes(tokenURI).length > 0 ? string.concat(s.baseURI, tokenURI) : s.uri;
    }
}
