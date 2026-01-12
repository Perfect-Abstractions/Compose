// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @notice Thrown when the sender address is invalid (e.g., zero address).
 * @param _sender The invalid sender address.
 */
error ERC721InvalidSender(address _sender);

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
 * @notice Mints a new ERC-721 token to the specified address.
 * @dev Reverts if the receiver address is zero or if the token already exists.
 * @param _to The address that will own the newly minted token.
 * @param _tokenId The ID of the token to mint.
 */
function mintERC721(address _to, uint256 _tokenId) {
    ERC721Storage storage s = getStorage();
    if (_to == address(0)) {
        revert ERC721InvalidReceiver(address(0));
    }
    if (s.ownerOf[_tokenId] != address(0)) {
        revert ERC721InvalidSender(address(0));
    }
    s.ownerOf[_tokenId] = _to;
    unchecked {
        s.balanceOf[_to]++;
    }
    emit Transfer(address(0), _to, _tokenId);
}

