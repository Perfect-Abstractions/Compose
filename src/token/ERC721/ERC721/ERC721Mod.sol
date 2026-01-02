// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-721 Library for Compose
 * @notice Provides internal logic for ERC-721 token management using diamond storage.
 *         This library is intended to be used by custom facets to integrate with ERC-721 functionality.
 * @dev Implements minting, burning, and transferring of ERC-721 tokens without dependencies.
 *      Uses ERC-8042-compliant storage definition and includes ERC-6093 standard custom errors.
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
 * @notice Thrown when an operator lacks sufficient approval to manage a token.
 * @param _operator The address attempting the unauthorized operation.
 * @param _tokenId The ID of the token involved.
 */
error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

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
bytes32 constant STORAGE_POSITION = keccak256("compose.erc721");

/*
 * @custom:storage-location erc8042:compose.erc721
 * @notice Storage layout for ERC-721 token management.
 * @dev Defines ownership, balances, approvals, and operator mappings per ERC-721 standard.
 */
struct ERC721Storage {
    mapping(uint256 tokenId => address owner) ownerOf;
    mapping(address owner => uint256 balance) balanceOf;
    mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
    mapping(uint256 tokenId => address approved) approved;
    string name;
    string symbol;
    string baseURI;
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

function setMetadata(string memory _name, string memory _symbol, string memory _baseURI) {
    ERC721Storage storage s = getStorage();
    s.name = _name;
    s.symbol = _symbol;
    s.baseURI = _baseURI;
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
    if (msg.sender != _from) {
        if (!s.isApprovedForAll[_from][msg.sender] && msg.sender != s.approved[_tokenId]) {
            revert ERC721InsufficientApproval(msg.sender, _tokenId);
        }
    }
    delete s.approved[_tokenId];
    unchecked {
        s.balanceOf[_from]--;
        s.balanceOf[_to]++;
    }
    s.ownerOf[_tokenId] = _to;
    emit Transfer(_from, _to, _tokenId);
}

/**
 * @notice Mints a new ERC-721 token to the specified address.
 * @dev Reverts if the receiver address is zero or if the token already exists.
 * @param _to The address that will own the newly minted token.
 * @param _tokenId The ID of the token to mint.
 */
function mint(address _to, uint256 _tokenId) {
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

/**
 * @notice Burns (destroys) a specific ERC-721 token.
 * @dev Reverts if the token does not exist. Clears ownership and approval.
 * @param _tokenId The ID of the token to burn.
 */
function burn(uint256 _tokenId) {
    ERC721Storage storage s = getStorage();
    address owner = s.ownerOf[_tokenId];
    if (owner == address(0)) {
        revert ERC721NonexistentToken(_tokenId);
    }
    delete s.ownerOf[_tokenId];
    delete s.approved[_tokenId];
    unchecked {
        s.balanceOf[owner]--;
    }
    emit Transfer(owner, address(0), _tokenId);
}
