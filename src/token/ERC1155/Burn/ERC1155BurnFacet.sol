// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Burn Facet
 * @notice Provides burn functionality for ERC-1155 tokens.
 */
contract ERC1155BurnFacet {
    /**
     * @notice Error indicating insufficient balance for a burn operation.
     * @param _sender Address attempting the burn.
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
     * @notice Error indicating array length mismatch in batch operations.
     * @param _idsLength Length of the ids array.
     * @param _valuesLength Length of the values array.
     */
    error ERC1155InvalidArrayLength(uint256 _idsLength, uint256 _valuesLength);

    /**
     * @notice Error indicating missing approval for an operator.
     * @param _operator Address attempting the operation.
     * @param _owner The token owner.
     */
    error ERC1155MissingApprovalForAll(address _operator, address _owner);

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
    function getStorage() internal pure returns (ERC1155Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Burns a single token type from an address.
     * @dev Emits a {TransferSingle} event.
     *      Caller must be the owner or an approved operator.
     * @param _from The address whose tokens will be burned.
     * @param _id The token type to burn.
     * @param _value The amount of tokens to burn.
     */
    function burn(address _from, uint256 _id, uint256 _value) external {
        if (_from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }

        ERC1155Storage storage s = getStorage();

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

        emit TransferSingle(msg.sender, _from, address(0), _id, _value);
    }

    /**
     * @notice Burns multiple token types from an address in a single transaction.
     * @dev Emits a {TransferBatch} event.
     *      Caller must be the owner or an approved operator.
     * @param _from The address whose tokens will be burned.
     * @param _ids The token types to burn.
     * @param _values The amounts of tokens to burn for each type.
     */
    function burnBatch(address _from, uint256[] calldata _ids, uint256[] calldata _values) external {
        if (_from == address(0)) {
            revert ERC1155InvalidSender(address(0));
        }
        if (_ids.length != _values.length) {
            revert ERC1155InvalidArrayLength(_ids.length, _values.length);
        }

        ERC1155Storage storage s = getStorage();

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
        }

        emit TransferBatch(msg.sender, _from, address(0), _ids, _values);
    }
}
