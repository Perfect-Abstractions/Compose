// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-721 Token Receiver Interface
 * @notice Interface for contracts that want to handle safe transfers of ERC-721 tokens.
 * @dev Contracts implementing this must return the selector to confirm token receipt.
 */
interface IERC721Receiver {
    /**
     * @notice Handles the receipt of an NFT.
     * @param _operator The address which called `safeTransferFrom`.
     * @param _from The previous owner of the token.
     * @param _tokenId The NFT identifier being transferred.
     * @param _data Additional data with no specified format.
     * @return The selector to confirm the token transfer.
     */
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes calldata _data)
        external
        returns (bytes4);
}
