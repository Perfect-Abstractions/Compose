// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Enumerable Token
 * @notice A complete, dependency-free ERC-721 implementation with enumeration support using a custom storage layout.
 * @dev Provides metadata, ownership, approvals, enumeration, safe transfers, minting, and burning features.
 */
contract ERC721EnumerableBurnFacet {
    /**
     * @notice Thrown when operating on a non-existent token.
     */
    error ERC721NonexistentToken(uint256 _tokenId);
    /**
     * @notice Thrown when the operator lacks sufficient approval for a transfer.
     */
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /**
     * @notice Emitted when a token is transferred between addresses.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    bytes32 constant STORAGE_POSITION = keccak256("erc721.enumerable");

    /**
     * @custom:storage-location erc8042:erc721.enumerable
     */
    struct ERC721EnumerableStorage {
        mapping(address owner => mapping(uint256 index => uint256 tokenId)) ownerTokens;
        mapping(uint256 tokenId => uint256 ownerTokensIndex) ownerTokensIndex;
        uint256[] allTokens;
        mapping(uint256 tokenId => uint256 allTokensIndex) allTokensIndex;
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

    bytes32 constant ERC721_STORAGE_POSITION = keccak256("erc721");

    /**
     * @custom:storage-location erc8042:erc721
     */
    struct ERC721Storage {
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256 balance) balanceOf;
        mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
        mapping(uint256 tokenId => address approved) approved;
    }

    /**
     * @notice Returns a pointer to the ERC-721 storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The ERC721Storage struct in storage.
     */
    function getERC721Storage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = ERC721_STORAGE_POSITION;
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
        ERC721Storage storage erc721Storage = getERC721Storage();
        address owner = erc721Storage.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }

        if (msg.sender != owner) {
            if (!erc721Storage.isApprovedForAll[owner][msg.sender] && msg.sender != erc721Storage.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
            }
        }

        delete erc721Storage.ownerOf[_tokenId];
        delete erc721Storage.approved[_tokenId];

        unchecked {
            /**
             * Remove from owner's list
             */
            uint256 tokenIndex = s.ownerTokensIndex[_tokenId];
            uint256 lastTokenIndex = erc721Storage.balanceOf[owner] - 1;
            if (tokenIndex != lastTokenIndex) {
                uint256 lastTokenId = s.ownerTokens[owner][lastTokenIndex];
                s.ownerTokens[owner][tokenIndex] = lastTokenId;
                s.ownerTokensIndex[lastTokenId] = tokenIndex;
            }
            erc721Storage.balanceOf[owner]--;

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
        }

        emit Transfer(owner, address(0), _tokenId);
    }
}
