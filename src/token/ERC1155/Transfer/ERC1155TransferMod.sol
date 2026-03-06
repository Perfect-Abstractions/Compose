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
 * @title ERC-1155 Transfer Module
 * @notice Provides internal transfer functionality for ERC-1155 tokens.
 */

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
 * @dev Storage position determined by the keccak256 hash of the diamond storage identifier.
 */
bytes32 constant STORAGE_POSITION = keccak256("erc1155");

/**
 * @dev ERC-8042 compliant storage struct for ERC-1155 token data.
 * @custom:storage-location erc8042:erc1155
 */
struct ERC1155Storage {
    mapping(uint256 id => mapping(address account => uint256 balance)) balanceOf;
    mapping(address account => mapping(address operator => bool)) isApprovedForAll;
}

/**
 * @notice Returns the ERC-1155 storage struct from the predefined diamond storage slot.
 * @dev Uses inline assembly to set the storage slot reference.
 * @return s The ERC-1155 storage struct reference.
 */
function getStorage() pure returns (ERC1155Storage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Safely transfers a single token type from one address to another.
 * @dev Validates ownership, approval, and receiver address before updating balances.
 *      Performs ERC1155Receiver validation if recipient is a contract (safe transfer).
 *      Complies with EIP-1155 safe transfer requirements.
 * @param _from The address to transfer from.
 * @param _to The address to transfer to.
 * @param _id The token type to transfer.
 * @param _value The amount of tokens to transfer.
 * @param _operator The address initiating the transfer (may be owner or approved operator).
 */
function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, address _operator) {
    if (_from == address(0)) {
        revert ERC1155InvalidSender(address(0));
    }
    if (_to == address(0)) {
        revert ERC1155InvalidReceiver(address(0));
    }

    ERC1155Storage storage s = getStorage();

    /**
     * Check authorization
     */
    if (_from != _operator && !s.isApprovedForAll[_from][_operator]) {
        revert ERC1155MissingApprovalForAll(_operator, _from);
    }

    uint256 fromBalance = s.balanceOf[_id][_from];

    if (fromBalance < _value) {
        revert ERC1155InsufficientBalance(_from, fromBalance, _value, _id);
    }

    unchecked {
        s.balanceOf[_id][_from] = fromBalance - _value;
    }
    s.balanceOf[_id][_to] += _value;

    emit TransferSingle(_operator, _from, _to, _id, _value);

    if (_to.code.length > 0) {
        try IERC1155Receiver(_to).onERC1155Received(_operator, _from, _id, _value, "") returns (bytes4 response) {
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
 * @notice Safely transfers multiple token types from one address to another in a single transaction.
 * @dev Validates ownership, approval, and receiver address before updating balances for each token type.
 *      Performs ERC1155Receiver validation if recipient is a contract (safe transfer).
 *      Complies with EIP-1155 safe transfer requirements.
 * @param _from The address to transfer from.
 * @param _to The address to transfer to.
 * @param _ids The token types to transfer.
 * @param _values The amounts of tokens to transfer for each type.
 * @param _operator The address initiating the transfer (may be owner or approved operator).
 */
function safeBatchTransferFrom(
    address _from,
    address _to,
    uint256[] memory _ids,
    uint256[] memory _values,
    address _operator
) {
    if (_from == address(0)) {
        revert ERC1155InvalidSender(address(0));
    }
    if (_to == address(0)) {
        revert ERC1155InvalidReceiver(address(0));
    }
    if (_ids.length != _values.length) {
        revert ERC1155InvalidArrayLength(_ids.length, _values.length);
    }

    ERC1155Storage storage s = getStorage();

    /**
     * Check authorization
     */
    if (_from != _operator && !s.isApprovedForAll[_from][_operator]) {
        revert ERC1155MissingApprovalForAll(_operator, _from);
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

    emit TransferBatch(_operator, _from, _to, _ids, _values);

    if (_to.code.length > 0) {
        try IERC1155Receiver(_to).onERC1155BatchReceived(_operator, _from, _ids, _values, "") returns (
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
