// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

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
contract ERC721Facet {
    /**
     * @notice Error indicating the queried owner address is invalid (zero address).
     */
    error ERC721InvalidOwner(address _owner);

    /**
     * @notice Error indicating that the queried token does not exist.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    /**
     * @notice Error indicating the sender does not match the token owner.
     */
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);

    /**
     * @notice Error indicating the sender address is invalid.
     */
    error ERC721InvalidSender(address _sender);

    /**
     * @notice Error indicating the receiver address is invalid.
     */
    error ERC721InvalidReceiver(address _receiver);

    /**
     * @notice Error indicating the operator lacks approval to transfer the given token.
     */
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /**
     * @notice Error indicating the approver address is invalid.
     */
    error ERC721InvalidApprover(address _approver);

    /**
     * @notice Error indicating the operator address is invalid.
     */
    error ERC721InvalidOperator(address _operator);

    /**
     * @notice Emitted when ownership of an NFT changes by any mechanism.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /**
     * @notice Emitted when the approved address for an NFT is changed or reaffirmed.
     */
    event Approval(address indexed _owner, address indexed _to, uint256 indexed _tokenId);

    /**
     * @notice Emitted when an operator is enabled or disabled for an owner.
     */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc721");

    /**
     * @custom:storage-location erc8042:compose.erc721
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
     * @notice Returns the token collection name.
     * @return The name of the token collection.
     */
    function name() external view returns (string memory) {
        return getStorage().name;
    }

    /**
     * @notice Returns the token collection symbol.
     * @return The symbol of the token collection.
     */
    function symbol() external view returns (string memory) {
        return getStorage().symbol;
    }

    /**
     * @notice Provide the metadata URI for a given token ID.
     * @param _tokenId tokenID of the NFT to query the metadata from
     * @return the URI providing the detailed metadata of the specified tokenID
     */
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        ERC721Storage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (bytes(s.baseURI).length == 0) {
            return "";
        }
        if (_tokenId == 0) {
            return string.concat(s.baseURI, "0");
        }
        /**
         * Convert _tokenId to string
         */
        uint256 temp = _tokenId;
        uint256 stringLength;
        while (temp != 0) {
            stringLength++;
            temp /= 10;
        }
        bytes memory tokenIdString = new bytes(stringLength);
        while (_tokenId != 0) {
            stringLength--;
            /**
             * Convert each digit to its ASCII representation
             * by adding 48 to get the ASCII code for the digit.
             * Then store it in the byte array
             */
            tokenIdString[stringLength] = bytes1(uint8(48 + (_tokenId % 10)));
            _tokenId /= 10;
        }
        return string.concat(s.baseURI, string(tokenIdString));
    }

    /**
     * @notice Returns the number of tokens owned by a given address.
     * @param _owner The address to query the balance of.
     * @return The balance (number of tokens) owned by `_owner`.
     */
    function balanceOf(address _owner) external view returns (uint256) {
        if (_owner == address(0)) {
            revert ERC721InvalidOwner(_owner);
        }
        return getStorage().balanceOf[_owner];
    }

    /**
     * @notice Returns the owner of a given token ID.
     * @param _tokenId The token ID to query.
     * @return The address of the token owner.
     */
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return owner;
    }

    /**
     * @notice Returns the approved address for a given token ID.
     * @param _tokenId The token ID to query the approval of.
     * @return The approved address for the token.
     */
    function getApproved(uint256 _tokenId) external view returns (address) {
        address owner = getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return getStorage().approved[_tokenId];
    }

    /**
     * @notice Returns true if an operator is approved to manage all of an owner's assets.
     * @param _owner The token owner.
     * @param _operator The operator address.
     * @return True if the operator is approved for all tokens of the owner.
     */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return getStorage().isApprovedForAll[_owner][_operator];
    }

    /**
     * @notice Approves another address to transfer the given token ID.
     * @param _to The address to be approved.
     * @param _tokenId The token ID to approve.
     */
    function approve(address _to, uint256 _tokenId) external {
        ERC721Storage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (msg.sender != owner && !s.isApprovedForAll[owner][msg.sender]) {
            revert ERC721InvalidApprover(msg.sender);
        }
        s.approved[_tokenId] = _to;
        emit Approval(owner, _to, _tokenId);
    }

    /**
     * @notice Approves or revokes permission for an operator to manage all caller's assets.
     * @param _operator The operator address to set approval for.
     * @param _approved True to approve, false to revoke.
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        if (_operator == address(0)) {
            revert ERC721InvalidOperator(_operator);
        }
        getStorage().isApprovedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
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
