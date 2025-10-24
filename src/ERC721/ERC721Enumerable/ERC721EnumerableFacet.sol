// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibUtils} from "../../Libraries/LibUtils.sol";

/// @title ERC721 Receiver Interface
/// @notice Interface for contracts that want to support safe ERC721 token transfers.
/// @dev Implementers must return the function selector to confirm token receipt.
interface IERC721Receiver {
    /// @notice Handles the receipt of an NFT.
    /// @param _operator The address which initiated the transfer.
    /// @param _from The previous owner of the token.
    /// @param _tokenId The NFT identifier being transferred.
    /// @param _data Additional data with no specified format.
    /// @return A bytes4 value indicating acceptance of the transfer.
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}

/// @title ERC-721 Enumerable Token
/// @notice A complete, dependency-free ERC-721 implementation with enumeration support using a custom storage layout.
/// @dev Provides metadata, ownership, approvals, enumeration, safe transfers, minting, and burning features.
contract ERC721EnumerableFacet {
    /// @notice Thrown when querying or transferring from an invalid owner address.
    error ERC721InvalidOwner(address _owner);
    /// @notice Thrown when operating on a non-existent token.
    error ERC721NonexistentToken(uint256 _tokenId);
    /// @notice Thrown when the provided owner does not match the actual owner of the token.
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);
    /// @notice Thrown when the sender address is invalid.
    error ERC721InvalidSender(address _sender);
    /// @notice Thrown when the receiver address is invalid.
    error ERC721InvalidReceiver(address _receiver);
    /// @notice Thrown when the operator lacks sufficient approval for a transfer.
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);
    /// @notice Thrown when an invalid approver is provided.
    error ERC721InvalidApprover(address _approver);
    /// @notice Thrown when an invalid operator is provided.
    error ERC721InvalidOperator(address _operator);
    /// @notice Thrown when an index is out of bounds during enumeration.
    error ERC721OutOfBoundsIndex(address _owner, uint256 _index);

    /// @notice Emitted when a token is transferred between addresses.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    /// @notice Emitted when a token is approved for transfer by another address.
    event Approval(address indexed _owner, address indexed _to, uint256 indexed _tokenId);
    /// @notice Emitted when an operator is approved or revoked for all tokens of an owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc721.enumerable");

    /// @custom:storage-location erc8042:compose.erc721.enumerable
    struct ERC721EnumerableStorage {
        string name;
        string symbol;
        string baseURI;
        mapping(uint256 tokenId => string tokenURI) tokenURIOf;
        mapping(uint256 tokenId => address owner) ownerOf;
        mapping(address owner => uint256[] ownedTokens) ownedTokensOf;
        mapping(uint256 tokenId => uint256 ownedTokensIndex) ownedTokensIndexOf;
        uint256[] allTokens;
        mapping(uint256 tokenId => uint256 allTokensIndex) allTokensIndexOf;
        mapping(uint256 tokenId => address approved) approved;
        mapping(address owner => mapping(address operator => bool approved)) isApprovedForAll;
    }

    /// @notice Returns the storage struct used by this facet.
    /// @return s The ERC721Enumerable storage struct.
    function _getStorage() internal pure returns (ERC721EnumerableStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Returns the name of the token collection.
    /// @return The token collection name.
    function name() external view returns (string memory) {
        return _getStorage().name;
    }

    /// @notice Returns the symbol of the token collection.
    /// @return The token symbol.
    function symbol() external view returns (string memory) {
        return _getStorage().symbol;
    }

    /// @notice Provide the metadata URI for a given token ID.
    /// @param _tokenId tokenID of the NFT to query the metadata from
    /// @return the URI providing the detailed metadata of the specified tokenID
    function tokenURI(uint256 _tokenId) external view returns (string memory) {
        ERC721EnumerableStorage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }

        if (bytes(s.baseURI).length == 0) {
            return "";
        }

        return string.concat(s.baseURI, LibUtils.toString(_tokenId));
    }

    /// @notice Returns the total number of tokens in existence.
    /// @return The total supply of tokens.
    function totalSupply() external view returns (uint256) {
        return _getStorage().allTokens.length;
    }

    /// @notice Returns the number of tokens owned by an address.
    /// @param _owner The address to query.
    /// @return The balance (number of tokens owned).
    function balanceOf(address _owner) external view returns (uint256) {
        if (_owner == address(0)) {
            revert ERC721InvalidOwner(_owner);
        }
        return _getStorage().ownedTokensOf[_owner].length;
    }

    /// @notice Returns the owner of a given token ID.
    /// @param _tokenId The token ID to query.
    /// @return The address of the token owner.
    function ownerOf(uint256 _tokenId) public view returns (address) {
        address owner = _getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return owner;
    }

    /// @notice Returns a token ID owned by a given address at a specific index.
    /// @param _owner The address to query.
    /// @param _index The index of the token.
    /// @return The token ID owned by `_owner` at `_index`.
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        ERC721EnumerableStorage storage s = _getStorage();
        if (_index >= s.ownedTokensOf[_owner].length) {
            revert ERC721OutOfBoundsIndex(_owner, _index);
        }
        return s.ownedTokensOf[_owner][_index];
    }

    /// @notice Returns the approved address for a given token ID.
    /// @param _tokenId The token ID to query.
    /// @return The approved address for the token.
    function getApproved(uint256 _tokenId) external view returns (address) {
        address owner = _getStorage().ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        return _getStorage().approved[_tokenId];
    }

    /// @notice Returns whether an operator is approved for all tokens of an owner.
    /// @param _owner The token owner.
    /// @param _operator The operator address.
    /// @return True if approved for all, false otherwise.
    function isApprovedForAll(address _owner, address _operator) external view returns (bool) {
        return _getStorage().isApprovedForAll[_owner][_operator];
    }

    /// @notice Approves another address to transfer a specific token ID.
    /// @param _to The address being approved.
    /// @param _tokenId The token ID to approve.
    function approve(address _to, uint256 _tokenId) external {
<<<<<<< HEAD
        ERC721EnumerableStorage storage s = _getStorage();
=======
        ERC721EnumerableStorage storage s = getStorage();
>>>>>>> upstream/main
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (msg.sender != owner && !s.isApprovedForAll[owner][msg.sender]) {
<<<<<<< HEAD
            revert ERC721InvalidApprover(_to);
=======
            revert ERC721InvalidApprover(msg.sender);
>>>>>>> upstream/main
        }
        s.approved[_tokenId] = _to;
        emit Approval(owner, _to, _tokenId);
    }

    /// @notice Approves or revokes an operator to manage all tokens of the caller.
    /// @param _operator The operator address.
    /// @param _approved True to approve, false to revoke.
    function setApprovalForAll(address _operator, bool _approved) external {
        if (_operator == address(0)) {
            revert ERC721InvalidOperator(_operator);
        }
        _getStorage().isApprovedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice Internal function to transfer ownership of a token ID.
    /// @param _from The address sending the token.
    /// @param _to The address receiving the token.
    /// @param _tokenId The token ID being transferred.
    function _transferFrom(address _from, address _to, uint256 _tokenId) internal {
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
        if (msg.sender != _from) {
            if (!s.isApprovedForAll[_from][msg.sender] && msg.sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
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

    /// @notice Transfers a token from one address to another.
    /// @param _from The current owner of the token.
    /// @param _to The recipient address.
    /// @param _tokenId The token ID to transfer.
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        _transferFrom(_from, _to, _tokenId);
    }

    /// @notice Safely transfers a token, checking for receiver contract compatibility.
    /// @param _from The current owner of the token.
    /// @param _to The recipient address.
    /// @param _tokenId The token ID to transfer.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        _transferFrom(_from, _to, _tokenId);
        if (_to.code.length > 0) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, "") returns (bytes4 returnValue) {
                if (returnValue != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) revert ERC721InvalidReceiver(_to);
                assembly ("memory-safe") {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }
    }

    /// @notice Safely transfers a token with additional data.
    /// @param _from The current owner of the token.
    /// @param _to The recipient address.
    /// @param _tokenId The token ID to transfer.
    /// @param _data Additional data to send to the receiver contract.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external {
        _transferFrom(_from, _to, _tokenId);
        if (_to.code.length > 0) {
            try IERC721Receiver(_to).onERC721Received(msg.sender, _from, _tokenId, _data) returns (bytes4 returnValue) {
                if (returnValue != IERC721Receiver.onERC721Received.selector) {
                    revert ERC721InvalidReceiver(_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) revert ERC721InvalidReceiver(_to);
                assembly ("memory-safe") {
                    revert(add(reason, 0x20), mload(reason))
                }
            }
        }
    }
}
