// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Multi Token Standard Interface
 * @notice Interface for ERC-1155 token contracts with custom errors
 * @dev This interface includes all custom errors used by ERC-1155 implementations (ERC-6093)
 */
interface IERC1155 {
    /**
     * @notice Error indicating insufficient balance for a transfer.
     * @param _sender Address attempting the transfer.
     * @param _balance Current balance of the sender.
     * @param _needed Amount required to complete the operation.
     * @param _tokenId The token ID involved.
     */
    error ERC1155InsufficientBalance(address _sender, uint256 _balance, uint256 _needed, uint256 _tokenId);

    /**
     * @notice Error indicating the sender address is invalid.
     * @param _sender Invalid sender address.
     */
    error ERC1155InvalidSender(address _sender);

    /**
     * @notice Error indicating the receiver address is invalid.
     * @param _receiver Invalid receiver address.
     */
    error ERC1155InvalidReceiver(address _receiver);

    /**
     * @notice Error indicating missing approval for an operator.
     * @param _operator Address attempting the operation.
     * @param _owner The token owner.
     */
    error ERC1155MissingApprovalForAll(address _operator, address _owner);

    /**
     * @notice Error indicating the approver address is invalid.
     * @param _approver Invalid approver address.
     */
    error ERC1155InvalidApprover(address _approver);

    /**
     * @notice Error indicating the operator address is invalid.
     * @param _operator Invalid operator address.
     */
    error ERC1155InvalidOperator(address _operator);

    /**
     * @notice Error indicating array length mismatch in batch operations.
     * @param _idsLength Length of the ids array.
     * @param _valuesLength Length of the values array.
     */
    error ERC1155InvalidArrayLength(uint256 _idsLength, uint256 _valuesLength);
    /**
     * @notice Emitted when `value` amount of tokens of type `id` are transferred from `from` to `to` by `operator`.
     * @param _operator The address which initiated the transfer.
     * @param _from The address which previously owned the token.
     * @param _to The address which now owns the token.
     * @param _id The token type being transferred.
     * @param _value The amount of tokens transferred.
     */

    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _value
    );

    /**
     * @notice Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all transfers.
     * @param _operator The address which initiated the batch transfer.
     * @param _from The address which previously owned the tokens.
     * @param _to The address which now owns the tokens.
     * @param _ids The token types being transferred.
     * @param _values The amounts of tokens transferred.
     */
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _values
    );

    /**
     * @notice Emitted when `account` grants or revokes permission to `operator` to transfer their tokens.
     * @param _account The token owner granting/revoking approval.
     * @param _operator The address being approved/revoked.
     * @param _approved True if approval is granted, false if revoked.
     */
    event ApprovalForAll(address indexed _account, address indexed _operator, bool _approved);

    /**
     * @notice Emitted when the URI for token type `id` changes to `value`.
     * @param _value The new URI for the token type.
     * @param _id The token type whose URI changed.
     */
    event URI(string _value, uint256 indexed _id);

    /**
     * @notice Returns the amount of tokens of token type `id` owned by `account`.
     * @param _account The address to query the balance of.
     * @param _id The token type to query.
     * @return The balance of the token type.
     */
    function balanceOf(address _account, uint256 _id) external view returns (uint256);

    /**
     * @notice Batched version of {balanceOf}.
     * @param _accounts The addresses to query the balances of (order and length must match _ids array).
     * @param _ids The token types to query (order and length must match _accounts array).
     * @return The balances of the token types.
     */
    function balanceOfBatch(address[] calldata _accounts, uint256[] calldata _ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @notice Grants or revokes permission to `operator` to transfer the caller's tokens.
     * @param _operator The address to grant/revoke approval to.
     * @param _approved True to approve, false to revoke.
     */
    function setApprovalForAll(address _operator, bool _approved) external;

    /**
     * @notice Returns true if `operator` is approved to transfer `account`'s tokens.
     * @param _account The token owner.
     * @param _operator The operator to query.
     * @return True if the operator is approved, false otherwise.
     */
    function isApprovedForAll(address _account, address _operator) external view returns (bool);

    /**
     * @notice Transfers `value` amount of token type `id` from `from` to `to`.
     * @param _from The address to transfer from.
     * @param _to The address to transfer to.
     * @param _id The token type to transfer.
     * @param _value The amount to transfer.
     * @param _data Additional data with no specified format.
     */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external;

    /**
     * @notice Batched version of {safeTransferFrom}.
     * @param _from The address to transfer from.
     * @param _to The address to transfer to.
     * @param _ids The token types to transfer (order and length must match _values array).
     * @param _values The amounts to transfer (order and length must match _ids array).
     * @param _data Additional data with no specified format.
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external;

    /**
     * @notice Returns the URI for token type `id`.
     * @param _id The token type to query.
     * @return The URI for the token type.
     */
    function uri(uint256 _id) external view returns (string memory);
}
