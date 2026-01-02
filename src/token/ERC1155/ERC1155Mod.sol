// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-1155 Token Receiver Interface
 * @notice Interface for contracts that want to handle safe transfers of ERC-1155 tokens.
 */
interface IERC1155Receiver {
    /*
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
 * @title LibERC1155 — ERC-1155 Library
 * @notice Provides internal functions and storage layout for ERC-1155 multi-token logic.
 * @dev Uses ERC-8042 for storage location standardization and ERC-6093 for error conventions.
 *      This library is intended to be used by custom facets to integrate with ERC-1155 functionality.
 */

/**
 * @notice Thrown when insufficient balance for a transfer or burn operation.
 * @param _sender Address attempting the operation.
 * @param _balance Current balance of the sender.
 * @param _needed Amount required to complete the operation.
 * @param _tokenId The token ID involved.
 */
error ERC1155InsufficientBalance(address _sender, uint256 _balance, uint256 _needed, uint256 _tokenId);

/**
 * @notice Thrown when the sender address is invalid.
 * @param _sender Invalid sender address.
 */
error ERC1155InvalidSender(address _sender);

/**
 * @notice Thrown when the receiver address is invalid.
 * @param _receiver Invalid receiver address.
 */
error ERC1155InvalidReceiver(address _receiver);

/**
 * @notice Thrown when array lengths don't match in batch operations.
 * @param _idsLength Length of the ids array.
 * @param _valuesLength Length of the values array.
 */
error ERC1155InvalidArrayLength(uint256 _idsLength, uint256 _valuesLength);

/**
 * @notice Thrown when missing approval for an operator.
 * @param _operator Address attempting the operation.
 * @param _owner The token owner.
 */
error ERC1155MissingApprovalForAll(address _operator, address _owner);

/**
 * @notice Emitted when a single token type is transferred.
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
 * @notice Emitted when multiple token types are transferred.
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
 * @notice Emitted when the URI for token type `_id` changes to `_value`.
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

/**
 * @notice Burns a single token type from an address.
 * @dev Decreases the balance and emits a TransferSingle event.
 *      Reverts if the account has insufficient balance.
 * @param _from The address whose tokens will be burned.
 * @param _id The token type to burn.
 * @param _value The amount of tokens to burn.
 */
function burn(address _from, uint256 _id, uint256 _value) {
    if (_from == address(0)) {
        revert ERC1155InvalidSender(address(0));
    }

    ERC1155Storage storage s = getStorage();
    uint256 fromBalance = s.balanceOf[_id][_from];

    if (fromBalance < _value) {
        revert ERC1155InsufficientBalance(_from, fromBalance, _value, _id);
    }

    unchecked {
        s.balanceOf[_id][_from] = fromBalance - _value;
    }

    emit TransferSingle(msg.sender, _from, address(0), _id, _value);
}

/**
 * @notice Burns multiple token types from an address in a single transaction.
 * @dev Decreases balances for each token type and emits a TransferBatch event.
 *      Reverts if the account has insufficient balance for any token type.
 * @param _from The address whose tokens will be burned.
 * @param _ids The token types to burn.
 * @param _values The amounts of tokens to burn for each type.
 */
function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) {
    if (_from == address(0)) {
        revert ERC1155InvalidSender(address(0));
    }
    if (_ids.length != _values.length) {
        revert ERC1155InvalidArrayLength(_ids.length, _values.length);
    }

    ERC1155Storage storage s = getStorage();

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
    }

    emit TransferBatch(msg.sender, _from, address(0), _ids, _values);
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

/**
 * @notice Sets the token-specific URI for a given token ID.
 * @dev Sets tokenURIs[_tokenId] to the provided string and emits a URI event with the full computed URI.
 *      The emitted URI is the concatenation of baseURI and the token-specific URI.
 * @param _tokenId The token ID to set the URI for.
 * @param _tokenURI The token-specific URI string to be concatenated with baseURI.
 */
function setTokenURI(uint256 _tokenId, string memory _tokenURI) {
    ERC1155Storage storage s = getStorage();
    s.tokenURIs[_tokenId] = _tokenURI;

    string memory fullURI = bytes(_tokenURI).length > 0 ? string.concat(s.baseURI, _tokenURI) : s.uri;
    emit URI(fullURI, _tokenId);
}

/**
 * @notice Sets the base URI prefix for token-specific URIs.
 * @dev The base URI is concatenated with token-specific URIs set via setTokenURI.
 *      Does not affect the default URI used when no token-specific URI is set.
 * @param _baseURI The base URI string to prepend to token-specific URIs.
 */
function setBaseURI(string memory _baseURI) {
    ERC1155Storage storage s = getStorage();
    s.baseURI = _baseURI;
}
