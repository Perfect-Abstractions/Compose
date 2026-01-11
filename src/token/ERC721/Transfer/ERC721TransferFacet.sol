// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/**
 * @title ERC-721 Token Receiver Interface
 * @notice Interface for contracts that want to handle safe transfers of ERC-721 tokens.
 * @dev Contracts implementing this must return the selector to confirm token receipt.
 */
interface IERC721Receiver {
    /**
     * @notice Handles the receipt of an NFT.
     * @param _operator The address which called `safeTransferFrom`.
     * @param _from The previous owner of the token.
     * @param _tokenId The NFT identifier being transferred.
     * @param _data Additional data with no specified format.
     * @return The selector to confirm the token transfer.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/**
 * @title ERC-721 Token
 * @notice A complete, dependency-free ERC-721 implementation using the diamond storage pattern.
 * @dev This facet provides metadata, ownership, approvals, safe transfers, minting, burning, and helpers.
 */
contract ERC721TransferFacet {
    /**
     * @notice Error indicating that the queried token does not exist.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    /**
     * @notice Error indicating the sender does not match the token owner.
     */
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);

    /**
     * @notice Error indicating the receiver address is invalid.
     */
    error ERC721InvalidReceiver(address _receiver);

    /**
     * @notice Error indicating the operator lacks approval to transfer the given token.
     */
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /**
     * @notice Emitted when ownership of an NFT changes by any mechanism.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    bytes32 constant STORAGE_POSITION = keccak256("erc721");

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
    function getStorage() internal pure returns (ERC721Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @dev Internal function to transfer a token, checking for ownership and approval.
     * @param _from The current owner of the token.
     * @param _to The address to receive the token.
     * @param _tokenId The token ID to transfer.
     */
    function internalTransferFrom(address _from, address _to, uint256 _tokenId) internal {
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
     * @notice Transfers a token from one address to another.
     * @param _from The current owner of the token.
     * @param _to The address to receive the token.
     * @param _tokenId The token ID to transfer.
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        internalTransferFrom(_from, _to, _tokenId);
    }

    /**
     * @notice Safely transfers a token, checking if the receiver can handle ERC-721 tokens.
     * @param _from The current owner of the token.
     * @param _to The address to receive the token.
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
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @notice Safely transfers a token with additional data.
     * @param _from The current owner of the token.
     * @param _to The address to receive the token.
     * @param _tokenId The token ID to transfer.
     * @param _data Additional data with no specified format.
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
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }
}
