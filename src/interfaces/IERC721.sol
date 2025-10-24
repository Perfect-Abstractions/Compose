// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-721 Token Standard Interface
/// @notice Interface for ERC-721 token contracts with custom errors
/// @dev This interface includes all custom errors used by ERC-721 implementations
interface IERC721 {
    /// @notice Error indicating the queried owner address is invalid (zero address).
    error ERC721InvalidOwner(address _owner);

    /// @notice Error indicating that the queried token does not exist.
    error ERC721NonexistentToken(uint256 _tokenId);

    /// @notice Error indicating the sender does not match the token owner.
    error ERC721IncorrectOwner(address _sender, uint256 _tokenId, address _owner);

    /// @notice Error indicating the sender address is invalid.
    error ERC721InvalidSender(address _sender);

    /// @notice Error indicating the receiver address is invalid.
    error ERC721InvalidReceiver(address _receiver);

    /// @notice Error indicating the operator lacks approval to transfer the given token.
    error ERC721InsufficientApproval(address _operator, uint256 _tokenId);

    /// @notice Error indicating the approver address is invalid.
    error ERC721InvalidApprover(address _approver);

    /// @notice Error indicating the operator address is invalid.
    error ERC721InvalidOperator(address _operator);

    /// @notice Emitted when ownership of an NFT changes by any mechanism.
    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    /// @notice Emitted when the approved address for an NFT is changed or reaffirmed.
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);

    /// @notice Emitted when an operator is enabled or disabled for an owner.
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    /// @notice Returns the token collection name.
    /// @return The name of the token collection.
    function name() external view returns (string memory);

    /// @notice Returns the token collection symbol.
    /// @return The symbol of the token collection.
    function symbol() external view returns (string memory);

    /// @notice Returns the number of tokens owned by a given address.
    /// @param _owner The address to query the balance of.
    /// @return The balance (number of tokens) owned by `_owner`.
    function balanceOf(address _owner) external view returns (uint256);

    /// @notice Returns the owner of a given token ID.
    /// @param _tokenId The token ID to query.
    /// @return The address of the token owner.
    function ownerOf(uint256 _tokenId) external view returns (address);

    /// @notice Returns the approved address for a given token ID.
    /// @param _tokenId The token ID to query the approval of.
    /// @return The approved address for the token.
    function getApproved(uint256 _tokenId) external view returns (address);

    /// @notice Returns true if an operator is approved to manage all of an owner's assets.
    /// @param _owner The token owner.
    /// @param _operator The operator address.
    /// @return True if the operator is approved for all tokens of the owner.
    function isApprovedForAll(address _owner, address _operator) external view returns (bool);

    /// @notice Approves another address to transfer the given token ID.
    /// @param _approved The address to be approved.
    /// @param _tokenId The token ID to approve.
    function approve(address _approved, uint256 _tokenId) external;

    /// @notice Approves or revokes permission for an operator to manage all caller's assets.
    /// @param _operator The operator address to set approval for.
    /// @param _approved True to approve, false to revoke.
    function setApprovalForAll(address _operator, bool _approved) external;

    /// @notice Transfers a token from one address to another.
    /// @param _from The current owner of the token.
    /// @param _to The address to receive the token.
    /// @param _tokenId The token ID to transfer.
    function transferFrom(address _from, address _to, uint256 _tokenId) external;

    /// @notice Safely transfers a token, checking if the receiver can handle ERC-721 tokens.
    /// @param _from The current owner of the token.
    /// @param _to The address to receive the token.
    /// @param _tokenId The token ID to transfer.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external;

    /// @notice Safely transfers a token with additional data.
    /// @param _from The current owner of the token.
    /// @param _to The address to receive the token.
    /// @param _tokenId The token ID to transfer.
    /// @param _data Additional data with no specified format.
    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external;

    /// @notice Provide the metadata URI for a given token ID.
    /// @param _tokenId tokenID of the NFT to query the metadata from
    /// @return the URI providing the detailed metadata of the specified tokenID
    function tokenURI(uint256 _tokenId) external view returns (string memory);
}

/// @title ERC-721 Token Receiver Interface
/// @notice Interface for contracts that want to handle safe transfers of ERC-721 tokens.
/// @dev Contracts implementing this must return the selector to confirm token receipt.
interface IERC721Receiver {
    /// @notice Handles the receipt of an NFT.
    /// @param _operator The address which called `safeTransferFrom`.
    /// @param _from The previous owner of the token.
    /// @param _tokenId The NFT identifier being transferred.
    /// @param _data Additional data with no specified format.
    /// @return The selector to confirm the token transfer.
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}
