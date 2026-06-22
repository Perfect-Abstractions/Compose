// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-1155 Multi Token Standard, optional metadata URI extension.
 * @dev  See https://eips.ethereum.org/EIPS/eip-1155
 *  Note: The ERC-165 identifier for this interface is 0x0e89341c.
 */
interface IERC1155Metadata_URI {
    /**
     * @notice Returns the URI for token type `id`.
     * @param _id The token type to query.
     * @return The URI for the token type.
     */
    function uri(uint256 _id) external view returns (string memory);
}
