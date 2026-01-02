// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Token Receiver Interface
 * @notice Interface that must be implemented by smart contracts in order to receive ERC-1155 token transfers.
 */
interface IERC1155Receiver {
    /**
     * @notice Handles the receipt of a single ERC-1155 token type.
     * @dev This function is called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * IMPORTANT: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param _operator The address which initiated the transfer (i.e. msg.sender).
     * @param _from The address which previously owned the token.
     * @param _id The ID of the token being transferred.
     * @param _value The amount of tokens being transferred.
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed.
     */
    function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data)
        external
        returns (bytes4);

    /**
     * @notice Handles the receipt of multiple ERC-1155 token types.
     * @dev This function is called at the end of a `safeBatchTransferFrom` after the balances have been updated.
     *
     * IMPORTANT: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param _operator The address which initiated the batch transfer (i.e. msg.sender).
     * @param _from The address which previously owned the token.
     * @param _ids An array containing ids of each token being transferred (order and length must match _values array).
     * @param _values An array containing amounts of each token being transferred (order and length must match _ids array).
     * @param _data Additional data with no specified format.
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed.
     */
    function onERC1155BatchReceived(
        address _operator,
        address _from,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4);
}

/**
 * @title ERC-1155 Multi Token Standard
 * @notice A complete, dependency-free ERC-1155 implementation using the diamond storage pattern.
 * @dev This facet provides balance queries, approvals, safe transfers, and URI management for multi-token contracts.
 *
 *      For developers creating custom facets that need to interact with ERC-1155 storage (e.g., custom minting logic),
 *      use the LibERC1155 library which provides helper functions to access this facet's storage.
 *      This facet does NOT depend on LibERC1155 - both access the same storage at keccak256("compose.erc1155").
 */
contract ERC1155Facet {
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
     * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc1155");

    /**
     * @dev ERC-8042 compliant storage struct for ERC-1155 token data.
     * @custom:storage-location erc8042:compose.erc1155
     */
    struct ERC1155Storage {
        mapping(uint256 id => mapping(address account => uint256 balance)) balanceOf;
        mapping(address account => mapping(address operator => bool)) isApprovedForAll;
        string uri;
        string baseURI;
        mapping(uint256 tokenId => string) tokenURIs;
    }

    /**
     * @notice Returns the ERC-1155 storage struct from the predefined diamond storage slot.
     * @dev Uses inline assembly to set the storage slot reference.
     * @return s The ERC-1155 storage struct reference.
     */
    function getStorage() internal pure returns (ERC1155Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Returns the URI for token type `_id`.
     * @dev If a token-specific URI is set in tokenURIs[_id], returns the concatenation of baseURI and tokenURIs[_id].
     *      Note that baseURI is empty by default and must be set explicitly if concatenation is desired.
     *      If no token-specific URI is set, returns the default URI which applies to all token types.
     *      The default URI may contain the substring `{id}` which clients should replace with the actual token ID.
     * @param _id The token ID to query.
     * @return The URI for the token type.
     */
    function uri(uint256 _id) external view returns (string memory) {
        ERC1155Storage storage s = getStorage();
        string memory tokenURI = s.tokenURIs[_id];

        return bytes(tokenURI).length > 0 ? string.concat(s.baseURI, tokenURI) : s.uri;
    }

    /**
     * @notice Returns the amount of tokens of token type `id` owned by `account`.
     * @param _account The address to query the balance of.
     * @param _id The token type to query.
     * @return The balance of the token type.
     */
    function balanceOf(address _account, uint256 _id) external view returns (uint256) {
        return getStorage().balanceOf[_id][_account];
    }

    /**
     * @notice Batched version of {balanceOf}.
     * @param _accounts The addresses to query the balances of.
     * @param _ids The token types to query.
     * @return balances The balances of the token types.
     */
    function balanceOfBatch(address[] calldata _accounts, uint256[] calldata _ids)
        external
        view
        returns (uint256[] memory balances)
    {
        if (_accounts.length != _ids.length) {
            revert ERC1155InvalidArrayLength(_ids.length, _accounts.length);
        }

        ERC1155Storage storage s = getStorage();
        balances = new uint256[](_accounts.length);

        for (uint256 i = 0; i < _accounts.length; i++) {
            balances[i] = s.balanceOf[_ids[i]][_accounts[i]];
        }
    }

    /**
     * @notice Grants or revokes permission to `operator` to transfer the caller's tokens.
     * @dev Emits an {ApprovalForAll} event.
     * @param _operator The address to grant/revoke approval to.
     * @param _approved True to approve, false to revoke.
     */
    function setApprovalForAll(address _operator, bool _approved) external {
        if (_operator == address(0)) {
            revert ERC1155InvalidOperator(address(0));
        }
        getStorage().isApprovedForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
     * @notice Returns true if `operator` is approved to transfer `account`'s tokens.
     * @param _account The token owner.
     * @param _operator The operator to query.
     * @return True if the operator is approved, false otherwise.
     */
    function isApprovedForAll(address _account, address _operator) external view returns (bool) {
        return getStorage().isApprovedForAll[_account][_operator];
    }

    /**
     * @notice Transfers `value` amount of token type `id` from `from` to `to`.
     * @dev Emits a {TransferSingle} event.
     * @param _from The address to transfer from.
     * @param _to The address to transfer to.
     * @param _id The token type to transfer.
     * @param _value The amount to transfer.
     * @param _data Additional data with no specified format.
     */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external {
        if (_to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (_from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }

        ERC1155Storage storage s = getStorage();

        /**
         * Check authorization
         */
        if (_from != msg.sender && !s.isApprovedForAll[_from][msg.sender]) {
            revert ERC1155MissingApprovalForAll(msg.sender, _from);
        }

        uint256 fromBalance = s.balanceOf[_id][_from];

        if (fromBalance < _value) {
            revert ERC1155InsufficientBalance(_from, fromBalance, _value, _id);
        }

        unchecked {
            s.balanceOf[_id][_from] = fromBalance - _value;
        }
        s.balanceOf[_id][_to] += _value;

        emit TransferSingle(msg.sender, _from, _to, _id, _value);

        if (_to.code.length > 0) {
            try IERC1155Receiver(_to).onERC1155Received(msg.sender, _from, _id, _value, _data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert ERC1155InvalidReceiver(_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC1155InvalidReceiver(_to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }

    /**
     * @notice Batched version of {safeTransferFrom}.
     * @dev Emits a {TransferBatch} event.
     * @param _from The address to transfer from.
     * @param _to The address to transfer to.
     * @param _ids The token types to transfer.
     * @param _values The amounts to transfer.
     * @param _data Additional data with no specified format.
     */
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {
        if (_to == address(0)) {
            revert ERC1155InvalidReceiver(address(0));
        }
        if (_from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        if (_ids.length != _values.length) {
            revert ERC1155InvalidArrayLength(_ids.length, _values.length);
        }

        ERC1155Storage storage s = getStorage();

        /**
         * Check authorization
         */
        if (_from != msg.sender && !s.isApprovedForAll[_from][msg.sender]) {
            revert ERC1155MissingApprovalForAll(msg.sender, _from);
        }

        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            uint256 value = _values[i];
            uint256 fromBalance = s.balanceOf[id][_from];

            if (fromBalance < value) {
                revert ERC1155InsufficientBalance(_from, fromBalance, value, id);
            }

            unchecked {
                s.balanceOf[id][_from] = fromBalance - value;
            }
            s.balanceOf[id][_to] += value;
        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _values);

        if (_to.code.length > 0) {
            try IERC1155Receiver(_to).onERC1155BatchReceived(msg.sender, _from, _ids, _values, _data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert ERC1155InvalidReceiver(_to);
                }
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert ERC1155InvalidReceiver(_to);
                } else {
                    assembly ("memory-safe") {
                        revert(add(reason, 0x20), mload(reason))
                    }
                }
            }
        }
    }
}
