// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Enumerable Burn Facet
 * @notice Provides an external burn entry point that composes with other ERC-721 enumerable facets.
 * @dev Keeps burn logic isolated so diamonds can opt-in without inheriting unrelated functionality.
 *      The corresponding library file for the facet that has the burn() internal function is in the LibERC721Enumerable.sol file.
 */
contract ERC721EnumerableBurnFacet {
    /**
     * @notice Thrown when attempting to interact with a non-existent token.
     * @param _tokenId The ID of the token that does not exist.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    /**
     * @notice Thrown when the caller lacks approval to operate on the token.
     * @param _operator The address attempting the unauthorized operation.
     * @param _tokenId The token ID involved in the failed operation.
     */
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /**
     * @notice Emitted when ownership of a token changes, including burning.
     * @param _from The address transferring the token (or owner when burning).
     * @param _to The address receiving the token (zero address when burning).
     * @param _tokenId The ID of the token being transferred.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc721.enumerable");

    /**
     * @custom:storage-location erc8042:compose.erc721.enumerable
     */
    struct ERC721EnumerableStorage {
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256[] ownerTokens) ownerTokens;
        mapping(uint256 tokenId => uint256 ownerTokensIndex) ownerTokensIndex;
        uint256[] allTokens;
        mapping(uint256 tokenId => uint256 allTokensIndex) allTokensIndex;
        mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
        mapping(uint256 tokenId => address approved) approved;
    }

    /**
     * @notice Returns the storage struct used by this facet.
     * @return s The ERC721Enumerable storage struct.
     */
    function getStorage() internal pure returns (ERC721EnumerableStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Burns (destroys) a token, removing it from enumeration tracking.
     * @param _tokenId The ID of the token to burn.
     */
    function burn(uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }

        if (msg.sender != owner) {
            if (!s.isApprovedForAll[owner][msg.sender] && msg.sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
            }
        }

        delete s.ownerOf[_tokenId];
        delete s.approved[_tokenId];

        /**
         * Remove from owner's list
         */
        uint256 tokenIndex = s.ownerTokensIndex[_tokenId];
        uint256 lastTokenIndex = s.ownerTokens[owner].length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.ownerTokens[owner][lastTokenIndex];
            s.ownerTokens[owner][tokenIndex] = lastTokenId;
            s.ownerTokensIndex[lastTokenId] = tokenIndex;
        }
        s.ownerTokens[owner].pop();

        /**
         * Remove from all tokens list
         */
        tokenIndex = s.allTokensIndex[_tokenId];
        lastTokenIndex = s.allTokens.length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.allTokens[lastTokenIndex];
            s.allTokens[tokenIndex] = lastTokenId;
            s.allTokensIndex[lastTokenId] = tokenIndex;
        }
        s.allTokens.pop();

        emit Transfer(owner, address(0), _tokenId);
    }
}
