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
