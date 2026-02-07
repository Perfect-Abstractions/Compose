// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-721 Transfer Module for Compose
 */

/**
 * @notice Thrown when attempting to interact with a non-existent token.
 * @param _tokenId The ID of the token that does not exist.
 */
error ERC721NonexistentToken(uint256 _tokenId);

/**
 * @notice Thrown when the sender is not the owner of the token.
 * @param _sender The address attempting the operation.
 * @param _tokenId The ID of the token being transferred.
 * @param _owner The actual owner of the token.
 */
error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);

/**
 * @notice Thrown when the receiver address is invalid (e.g., zero address).
 * @param _receiver The invalid receiver address.
 */
error ERC721InvalidReceiver(address _receiver);

/**
 * @notice Emitted when ownership of a token changes, including minting and burning.
 * @param _from The address transferring the token, or zero for minting.
 * @param _to The address receiving the token, or zero for burning.
 * @param _tokenId The ID of the token being transferred.
 */
event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

/**
 * @dev Storage position constant defined via keccak256 hash of diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("erc721");

/*
 * @custom:storage-location erc8042:erc721
 * @notice Storage layout for ERC-721 token management.
 * @dev Defines ownership, balances, approvals, and operator mappings per ERC-721 standard.
 */
struct ERC721Storage {
    mapping(uint256 tokenId => address owner) ownerOf;
    mapping(address owner => uint256 balance) balanceOf;
    mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
    mapping(uint256 tokenId => address approved) approved;
}

/**
 * @notice Returns the ERC-721 storage struct from its predefined slot.
 * @dev Uses inline assembly to access diamond storage location.
 * @return s The storage reference for ERC-721 state variables.
 */
function getStorage() pure returns (ERC721Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Transfers ownership of a token ID from one address to another.
 * @dev Validates ownership, approval, and receiver address before updating state.
 * @param _from The current owner of the token.
 * @param _to The address that will receive the token.
 * @param _tokenId The ID of the token being transferred.
 */
function transferFrom(address _from, address _to, uint256 _tokenId) {
    ERC721Storage storage s = getStorage();
    if (_to == address(0)) {
        revert ERC721InvalidReceiver(address(0));
    }
    address owner = s.ownerOf[_tokenId];
    if (owner == address(0)) {
        revert ERC721NonexistentToken(_tokenId);
    }
    if (owner != _from) {
        revert ERC721IncorrectOwner(_from, _tokenId, owner);
    }
    delete s.approved[_tokenId];
    unchecked {
        s.balanceOf[_from]--;
        s.balanceOf[_to]++;
    }
    s.ownerOf[_tokenId] = _to;
    emit Transfer(_from, _to, _tokenId);
}

