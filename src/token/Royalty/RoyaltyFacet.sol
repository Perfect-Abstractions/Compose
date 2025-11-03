// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title Royalty Facet - ERC-2981 NFT Royalty Standard Implementation
/// @notice Implements royalty queries for NFT secondary sales per ERC-2981 standard.
/// @dev Provides standardized royalty information to NFT marketplaces and platforms.
///      Supports both default and per-token royalty configurations using diamond storage.
///      This is an implementation of the ERC-2981 NFT Royalty Standard.
contract RoyaltyFacet {
    /// @notice Thrown when default royalty fee exceeds 100% (10000 basis points).
    /// @param _numerator The fee numerator that exceeds the denominator.
    /// @param _denominator The fee denominator (10000 basis points).
    error ERC2981InvalidDefaultRoyalty(uint256 _numerator, uint256 _denominator);

    /// @notice Thrown when default royalty receiver is the zero address.
    /// @param _receiver The invalid receiver address.
    error ERC2981InvalidDefaultRoyaltyReceiver(address _receiver);

    /// @notice Thrown when token-specific royalty fee exceeds 100% (10000 basis points).
    /// @param _tokenId The token ID with invalid royalty configuration.
    /// @param _numerator The fee numerator that exceeds the denominator.
    /// @param _denominator The fee denominator (10000 basis points).
    error ERC2981InvalidTokenRoyalty(uint256 _tokenId, uint256 _numerator, uint256 _denominator);

    /// @notice Thrown when token-specific royalty receiver is the zero address.
    /// @param _tokenId The token ID with invalid royalty configuration.
    /// @param _receiver The invalid receiver address.
    error ERC2981InvalidTokenRoyaltyReceiver(uint256 _tokenId, address _receiver);

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc2981");

    /// @dev The denominator with which to interpret royalty fees as a percentage of sale price.
    ///      Expressed in basis points where 10000 = 100%. This value aligns with the ERC-2981
    ///      specification and marketplace expectations. Implemented as a constant for gas efficiency
    ///      rather than the virtual function pattern, as Compose does not support inheritance-based
    ///      customization. To modify this value, deploy a custom facet implementation.
    uint96 constant FEE_DENOMINATOR = 10000;

    /// @notice Structure containing royalty information.
    /// @param receiver The address that will receive royalty payments.
    /// @param royaltyFraction The royalty fee expressed in basis points.
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    /// @custom:storage-location erc8042:compose.erc2981
    struct RoyaltyStorage {
        RoyaltyInfo defaultRoyaltyInfo;
        mapping(uint256 tokenId => RoyaltyInfo) tokenRoyaltyInfo;
    }

    /// @notice Returns a pointer to the royalty storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s The RoyaltyStorage struct in storage.
    function getStorage() internal pure returns (RoyaltyStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Returns royalty information for a given token and sale price.
    /// @dev Returns token-specific royalty if set, otherwise falls back to default royalty.
    ///      Royalty amount is calculated as a percentage of the sale price using basis points.
    ///      Implements the ERC-2981 royaltyInfo function.
    /// @param _tokenId The NFT asset queried for royalty information.
    /// @param _salePrice The sale price of the NFT asset specified by _tokenId.
    /// @return receiver The address designated to receive the royalty payment.
    /// @return royaltyAmount The royalty payment amount for _salePrice.
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyStorage storage s = getStorage();
        RoyaltyInfo memory royalty = s.tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = s.defaultRoyaltyInfo;
        }

        receiver = royalty.receiver;
        royaltyAmount = (_salePrice * royalty.royaltyFraction) / FEE_DENOMINATOR;
    }
}
