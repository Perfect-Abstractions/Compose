// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @notice Thrown when the sender address is invalid.
 * @param _sender The invalid sender address.
 */
error ERC721InvalidSender(address _sender);

/**
 * @notice Thrown when the receiver address is invalid.
 * @param _receiver The invalid receiver address.
 */
error ERC721InvalidReceiver(address _receiver);

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
function getStorage() pure returns (ERC721EnumerableStorage storage s) {
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
function getERC721Storage() pure returns (ERC721Storage storage s) {
    bytes32 position = ERC721_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Mints a new ERC-721 token to the specified address, adding it to enumeration lists.
 * @dev Reverts if the receiver address is zero or if the token already exists.
 * @param _to The address that will own the newly minted token.
 * @param _tokenId The ID of the token to mint.
 */
function mint(address _to, uint256 _tokenId) {
    ERC721EnumerableStorage storage s = getStorage();
    ERC721Storage storage erc721Storage = getERC721Storage();
    if (_to == address(0)) {
        revert ERC721InvalidReceiver(address(0));
    }
    if (erc721Storage.ownerOf[_tokenId] != address(0)) {
        revert ERC721InvalidSender(address(0));
    }

    erc721Storage.ownerOf[_tokenId] = _to;
    uint256 tokenIndex = erc721Storage.balanceOf[_to];
    s.ownerTokensIndex[_tokenId] = tokenIndex;
    s.ownerTokens[_to][tokenIndex] = _tokenId;
    unchecked {
        erc721Storage.balanceOf[_to] = tokenIndex + 1;
    }
    s.allTokensIndex[_tokenId] = s.allTokens.length;
    s.allTokens.push(_tokenId);
    emit Transfer(address(0), _to, _tokenId);
}

