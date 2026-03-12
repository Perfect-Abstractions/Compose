// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Enumerable Token Standard Interface
 * @notice Interface for ERC-721 token contracts with enumeration support and custom errors
 * @dev This interface includes all custom errors used by ERC-721 Enumerable implementations
 */
interface IERC721Enumerable {
    /**
     * @notice Thrown when querying or transferring from an invalid owner address.
     */
    error ERC721InvalidOwner(address _owner);

    /**
     * @notice Thrown when operating on a non-existent token.
     */
    error ERC721NonexistentToken(uint256 _tokenId);

    /**
     * @notice Thrown when the provided owner does not match the actual owner of the token.
     */
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);

    /**
     * @notice Thrown when the sender address is invalid.
     */
    error ERC721InvalidSender(address _sender);

    /**
     * @notice Thrown when the receiver address is invalid.
     */
    error ERC721InvalidReceiver(address _receiver);

    /**
     * @notice Thrown when the operator lacks sufficient approval for a transfer.
     */
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /**
     * @notice Thrown when an invalid approver is provided.
     */
    error ERC721InvalidApprover(address _approver);

    /**
     * @notice Thrown when an invalid operator is provided.
     */
    error ERC721InvalidOperator(address _operator);

    /**
     * @notice Thrown when an index is out of bounds during enumeration.
     */
    error ERC721OutOfBoundsIndex(address _owner, uint256 _index);

    /**
     * @notice Emitted when a token is transferred between addresses.
     */
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /**
     * @notice Emitted when a token is approved for transfer by another address.
     */
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /**
     * @notice Emitted when an operator is approved or revoked for all tokens of an owner.
     */
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /**
     * @notice Returns the name of the token collection.
     * @return The token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @notice Returns the symbol of the token collection.
     * @return The token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @notice Returns the total number of tokens in existence.
     * @return The total supply of tokens.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice Returns the number of tokens owned by an address.
     * @param _owner The address to query.
     * @return The balance (number of tokens owned).
     */
    function balanceOf(address _owner) external view returns (uint256);

    /**
     * @notice Returns the owner of a given token ID.
     * @param _tokenId The token ID to query.
     * @return The address of the token owner.
     */
    function ownerOf(uint256 _tokenId) external view returns (address);

    /**
     * @notice Returns a token ID owned by a given address at a specific index.
     * @param _owner The address to query.
     * @param _index The index of the token.
     * @return The token ID owned by `_owner` at `_index`.
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256);

    /**
     * @notice Returns the approved address for a given token ID.
     * @param _tokenId The token ID to query.
     * @return The approved address for the token.
     */
    function getApproved(uint256 _tokenId) external view returns (address);

    /**
     * @notice Returns whether an operator is approved for all tokens of an owner.
     * @param _owner The token owner.
     * @param _operator The operator address.
     * @return True if approved for all, false otherwise.
     */
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    /**
     * @notice Approves another address to transfer a specific token ID.
     * @param _approved The address being approved.
     * @param _tokenId The token ID to approve.
     */
    function approve(address _approved, uint256 _tokenId) external;

    /**
     * @notice Approves or revokes an operator to manage all tokens of the caller.
     * @param _operator The operator address.
     * @param _approved True to approve, false to revoke.
     */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
     * @notice Transfers a token from one address to another.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The token ID to transfer.
     */
    function transferFrom(address _from, address _to, uint256 _tokenId) external;

    /**
     * @notice Safely transfers a token, checking for receiver contract compatibility.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The token ID to transfer.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;

    /**
     * @notice Safely transfers a token with additional data.
     * @param _from The current owner of the token.
     * @param _to The recipient address.
     * @param _tokenId The token ID to transfer.
     * @param _data Additional data to send to the receiver.
     */
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external;
}
