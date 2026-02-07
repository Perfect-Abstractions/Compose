// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-2981 NFT Royalty Standard Interface
 * @notice Interface for ERC-2981 royalty information with custom errors
 * @dev This interface includes all custom errors used by ERC-2981 implementations
 */
interface IERC2981 {
    /**
     * @notice Error indicating the default royalty fee exceeds 100% (10000 basis points).
     */
    error ERC2981InvalidDefaultRoyalty(uint256 _numerator, uint256 _denominator);

    /**
     * @notice Error indicating the default royalty receiver is the zero address.
     */
    error ERC2981InvalidDefaultRoyaltyReceiver(address _receiver);

    /**
     * @notice Error indicating a token-specific royalty fee exceeds 100% (10000 basis points).
     */
    error ERC2981InvalidTokenRoyalty(uint256 _tokenId, uint256 _numerator, uint256 _denominator);

    /**
     * @notice Error indicating a token-specific royalty receiver is the zero address.
     */
    error ERC2981InvalidTokenRoyaltyReceiver(uint256 _tokenId, address _receiver);

    /**
     * @notice Returns royalty information for a given token and sale price.
     * @dev Called with the sale price to determine how much royalty is owed and to whom.
     *      Implementations MUST calculate royalty as a percentage of the sale price.
     * @param _tokenId The NFT asset queried for royalty information.
     * @param _salePrice The sale price of the NFT asset specified by _tokenId.
     * @return receiver The address designated to receive the royalty payment.
     * @return royaltyAmount The royalty payment amount for _salePrice.
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}
