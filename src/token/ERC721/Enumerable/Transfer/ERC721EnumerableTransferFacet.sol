// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC721 Receiver Interface
 * @notice Interface for contracts that want to support safe ERC721 token transfers.
 * @dev Implementers must return the function selector to confirm token receipt.
 */
interface IERC721Receiver {
    /**
     * @notice Handles the receipt of an NFT.
     * @param _operator The address which initiated the transfer.
     * @param _from The previous owner of the token.
     * @param _tokenId The NFT identifier being transferred.
     * @param _data Additional data with no specified format.
     * @return A bytes4 value indicating acceptance of the transfer.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/**
 * @title ERC-721 Enumerable Token
 * @notice A complete, dependency-free ERC-721 implementation with enumeration support using a custom storage layout.
 * @dev Provides metadata, ownership, approvals, enumeration, safe transfers, minting, and burning features.
 */
contract ERC721EnumerableTransferFacet {
    /**
     * @notice Thrown when operating on a non-existent token.
     */
    error ERC721NonexistentToken(uint256 _tokenId);
    /**
     * @notice Thrown when the provided owner does not match the actual owner of the token.
     */
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);
    /**
     * @notice Thrown when the receiver address is invalid.
     */
    error ERC721InvalidReceiver(address _receiver);
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
     * @notice Internal function to transfer ownership of a token ID.
     * @param _from The address sending the token.
     * @param _to The address receiving the token.
     * @param _tokenId The token ID being transferred.
     */
    function internalTransferFrom(address _from, address _to, uint256 _tokenId) internal {
        ERC721EnumerableStorage storage s = getStorage();
        ERC721Storage storage erc721Storage = getERC721Storage();
        if (_to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address owner = erc721Storage.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (owner != _from) {
            revert ERC721IncorrectOwner(_from, _tokenId, owner);
        }
        if (msg.sender != _from) {
            if (!erc721Storage.isApprovedForAll[_from][msg.sender] && msg.sender != erc721Storage.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
            }
        }
        delete erc721Storage.approved[_tokenId];
        unchecked {
            uint256 tokenIndex = s.ownerTokensIndex[_tokenId];
            uint256 lastTokenIndex = erc721Storage.balanceOf[_from] - 1;
            if (tokenIndex != lastTokenIndex) {
                uint256 lastTokenId = s.ownerTokens[_from][lastTokenIndex];
                s.ownerTokens[_from][tokenIndex] = lastTokenId;
                s.ownerTokensIndex[lastTokenId] = tokenIndex;
            }
            erc721Storage.balanceOf[_from]--;

            tokenIndex = erc721Storage.balanceOf[_to];
            s.ownerTokensIndex[_tokenId] = tokenIndex;
            s.ownerTokens[_to][tokenIndex] = _tokenId;
            erc721Storage.balanceOf[_to] = tokenIndex + 1;
            erc721Storage.ownerOf[_tokenId] = _to;
        }
        emit Transfer(_from, _to, _tokenId);
    }

    /**
     * @notice Transfers a token from one address to another.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The token ID to transfer.
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        internalTransferFrom(_from, _to, _tokenId);
    }

    /**
     * @notice Safely transfers a token, checking for receiver contract compatibility.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The token ID to transfer.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        internalTransferFrom(_from, _to, _tokenId);
        if (_to.code.length > 0) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, "") returns (bytes4 returnValue) {
                if (returnValue != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(_to);
                }
                assembly ("memory-safe") {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }
    }

    /**
     * @notice Safely transfers a token with additional data.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The token ID to transfer.
     * @param _data Additional data to send to the receiver contract.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external {
        internalTransferFrom(_from, _to, _tokenId);
        if (_to.code.length > 0) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 returnValue) {
                if (returnValue != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC721InvalidReceiver(_to);
                }
                assembly ("memory-safe") {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }
    }
}
