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
 * @title ERC-1155 Mint Module
 * @notice Provides internal mint functionality for ERC-1155 tokens.
 */

/**
 * @notice Error indicating the receiver address is invalid.
 * @param _receiver Invalid receiver address.
 */
error ERC1155InvalidReceiver(address _receiver);

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
 * @notice Mints a single token type to an address.
 * @dev Increases the balance and emits a TransferSingle event.
 *      Performs receiver validation if recipient is a contract.
 * @param _to The address that will receive the tokens.
 * @param _id The token type to mint.
 * @param _value The amount of tokens to mint.
 * @param _data Additional data with no specified format.
 */
function mint(address _to, uint256 _id, uint256 _value, bytes memory _data) {
    if (_to == address(0)) {
        revert ERC1155InvalidReceiver(address(0));
    }

    ERC1155Storage storage s = getStorage();
    s.balanceOf[_id][_to] += _value;

    emit TransferSingle(msg.sender, address(0), _to, _id, _value);

    if (_to.code.length > 0) {
        try IERC1155Receiver(_to).onERC1155Received(msg.sender, address(0), _id, _value, _data) returns (
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
 * @notice Mints multiple token types to an address in a single transaction.
 * @dev Increases balances for each token type and emits a TransferBatch event.
 *      Performs receiver validation if recipient is a contract.
 * @param _to The address that will receive the tokens.
 * @param _ids The token types to mint.
 * @param _values The amounts of tokens to mint for each type.
 * @param _data Additional data with no specified format.
 */
function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) {
    if (_to == address(0)) {
        revert ERC1155InvalidReceiver(address(0));
    }
    if (_ids.length != _values.length) {
        revert ERC1155InvalidArrayLength(_ids.length, _values.length);
    }

    ERC1155Storage storage s = getStorage();

    for (uint256 i = 0; i < _ids.length; i++) {
        s.balanceOf[_ids[i]][_to] += _values[i];
    }

    emit TransferBatch(msg.sender, address(0), _to, _ids, _values);

    if (_to.code.length > 0) {
        try IERC1155Receiver(_to).onERC1155BatchReceived(msg.sender, address(0), _ids, _values, _data) returns (
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
