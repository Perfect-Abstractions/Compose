// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-721 Enumerable Library for Compose
/// @notice Provides internal logic for enumerable ERC-721 tokens using diamond storage.
/// @dev Implements ERC-721 operations with token enumeration support (tracking owned and global tokens).
/// Follows ERC-8042 for storage layout and ERC-6093 for standardized custom errors.
library LibERC721 {
    /// @notice Thrown when attempting to interact with a non-existent token.
    /// @param _tokenId The ID of the token that does not exist.
    error ERC721NonexistentToken(uint256 _tokenId);

    /// @notice Thrown when the sender is not the owner of the token.
    /// @param _sender The address attempting the operation.
    /// @param _tokenId The ID of the token being transferred.
    /// @param _owner The actual owner of the token.
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);

    /// @notice Thrown when the sender address is invalid.
    /// @param _sender The invalid sender address.
    error ERC721InvalidSender(address _sender);

    /// @notice Thrown when the receiver address is invalid.
    /// @param _receiver The invalid receiver address.
    error ERC721InvalidReceiver(address _receiver);

    /// @notice Thrown when an operator lacks approval to manage a token.
    /// @param _operator The address attempting the unauthorized operation.
    /// @param _tokenId The ID of the token involved.
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /// @notice Emitted when ownership of a token changes, including minting and burning.
    /// @param _from The address transferring the token, or zero for minting.
    /// @param _to The address receiving the token, or zero for burning.
    /// @param _tokenId The ID of the token being transferred.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @dev Storage slot defined via keccak256 hash of the diamond storage identifier.
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc721.enumerable");

    /// @custom:storage-location erc8042:compose.erc721.enumerable
    /// @notice Storage layout for ERC-721 enumerable tokens.
    /// @dev Includes mappings for ownership, approvals, operator permissions, and enumeration tracking.
    struct ERC721EnumerableStorage {
        string name;
        string symbol;
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256[] ownedTokens) ownedTokensOf;
        mapping(uint256 tokenId => uint256 ownedTokensIndex) ownedTokensIndexOf;
        uint256[] allTokens;
        mapping(uint256 tokenId => uint256 allTokensIndex) allTokensIndexOf;
        mapping(uint256 tokenId => address approved) approved;
        mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
    }

    /// @notice Returns the ERC-721 enumerable storage struct from its predefined slot.
    /// @dev Uses inline assembly to point to the correct diamond storage position.
    /// @return s The storage reference for ERC-721 enumerable state variables.
    function _getStorage() internal pure returns (ERC721EnumerableStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Transfers a token ID from one address to another, updating enumeration data.
    /// @dev Validates ownership, approval, and receiver address before state updates.
    /// @param _from The current owner of the token.
    /// @param _to The address receiving the token.
    /// @param _tokenId The ID of the token being transferred.
    /// @param _sender The initiator of the transfer (may be owner or approved operator).
    function _transferFrom(address _from, address _to, uint256 _tokenId, address _sender) internal {
        ERC721EnumerableStorage storage s = _getStorage();
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
        if (_sender != _from) {
            if (!s.isApprovedForAll[_from][_sender] && _sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(_sender, _tokenId);
            }
        }

        delete s.approved[_tokenId];

        uint256 tokenIndex = s.ownedTokensIndexOf[_tokenId];
        uint256 lastTokenIndex = s.ownedTokensOf[_from].length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.ownedTokensOf[_from][lastTokenIndex];
            s.ownedTokensOf[_from][tokenIndex] = lastTokenId;
            s.ownedTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.ownedTokensOf[_from].pop();

        s.ownedTokensIndexOf[_tokenId] = s.ownedTokensOf[_to].length;
        s.ownedTokensOf[_to].push(_tokenId);
        s.ownerOf[_tokenId] = _to;
        emit Transfer(_from, _to, _tokenId);
    }

    /// @notice Mints a new ERC-721 token to the specified address, adding it to enumeration lists.
    /// @dev Reverts if the receiver address is zero or if the token already exists.
    /// @param _to The address that will own the newly minted token.
    /// @param _tokenId The ID of the token to mint.
    function _mint(address _to, uint256 _tokenId) internal {
        ERC721EnumerableStorage storage s = _getStorage();
        if (_to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        if (s.ownerOf[_tokenId] != address(0)) {
            revert ERC721InvalidSender(address(0));
        }

        s.ownedTokensIndexOf[_tokenId] = s.ownedTokensOf[_to].length;
        s.ownedTokensOf[_to].push(_tokenId);
        s.allTokensIndexOf[_tokenId] = s.allTokens.length;
        s.allTokens.push(_tokenId);
        emit Transfer(address(0), _to, _tokenId);
    }

    /// @notice Burns (destroys) an existing ERC-721 token, removing it from enumeration lists.
    /// @dev Reverts if the token does not exist or if the sender is not authorized.
    /// @param _tokenId The ID of the token to burn.
    /// @param _sender The address initiating the burn.
    function _burn(uint256 _tokenId, address _sender) internal {
        ERC721EnumerableStorage storage s = _getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (_sender != owner) {
            if (!s.isApprovedForAll[owner][_sender] && _sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(_sender, _tokenId);
            }
        }

        delete s.ownerOf[_tokenId];
        delete s.approved[_tokenId];

        uint256 tokenIndex = s.ownedTokensIndexOf[_tokenId];
        uint256 lastTokenIndex = s.ownedTokensOf[owner].length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.ownedTokensOf[owner][lastTokenIndex];
            s.ownedTokensOf[owner][tokenIndex] = lastTokenId;
            s.ownedTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.ownedTokensOf[owner].pop();

        tokenIndex = s.allTokensIndexOf[_tokenId];
        lastTokenIndex = s.allTokens.length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.allTokens[lastTokenIndex];
            s.allTokens[tokenIndex] = lastTokenId;
            s.allTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.allTokens.pop();
        emit Transfer(owner, address(0), _tokenId);
    }
}
