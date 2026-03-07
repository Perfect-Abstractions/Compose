// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Metadata Module
 * @notice Provides internal metadata functionality for ERC-1155 tokens.
 */

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
function getStorage() pure returns (ERC1155MetadataStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Sets the token-specific URI for a given token ID.
 * @dev Sets tokenURIs[_tokenId] to the provided string and emits a URI event with the full computed URI.
 *      The emitted URI is the concatenation of baseURI and the token-specific URI.
 * @param _tokenId The token ID to set the URI for.
 * @param _tokenURI The token-specific URI string to be concatenated with baseURI.
 */
function setTokenURI(uint256 _tokenId, string memory _tokenURI) {
    ERC1155MetadataStorage storage s = getStorage();
    s.tokenURIs[_tokenId] = _tokenURI;

    string memory fullURI = bytes(_tokenURI).length > 0 ? string.concat(s.baseURI, _tokenURI) : s.uri;
    emit URI(fullURI, _tokenId);
}

/**
 * @notice Sets the base URI prefix for token-specific URIs.
 * @dev The base URI is concatenated with token-specific URIs set via setTokenURI.
 *      Does not affect the default URI used when no token-specific URI is set.
 * @param _baseURI The base URI string to prepend to token-specific URIs.
 */
function setBaseURI(string memory _baseURI) {
    ERC1155MetadataStorage storage s = getStorage();
    s.baseURI = _baseURI;
}

/**
 * @notice Sets the default URI for all token types.
 * @dev This URI is used when no token-specific URI is set.
 * @param _uri The default URI string.
 */
function setURI(string memory _uri) {
    ERC1155MetadataStorage storage s = getStorage();
    s.uri = _uri;
}
