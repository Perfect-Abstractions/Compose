// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title LibRoyalty - ERC-2981 Royalty Standard Library
 * @notice Provides internal functions and storage layout for ERC-2981 royalty logic.
 * @dev Uses ERC-8042 for storage location standardization. Compatible with OpenZeppelin's ERC2981 behavior.
 *      This is an implementation of the ERC-2981 NFT Royalty Standard.
 */

/**
 * @notice Thrown when default royalty fee exceeds 100% (10000 basis points).
 * @param _numerator The fee numerator that exceeds the denominator.
 * @param _denominator The fee denominator (10000 basis points).
 */
error ERC2981InvalidDefaultRoyalty(uint256 _numerator, uint256 _denominator);

/**
 * @notice Thrown when default royalty receiver is the zero address.
 * @param _receiver The invalid receiver address.
 */
error ERC2981InvalidDefaultRoyaltyReceiver(address _receiver);

/**
 * @notice Thrown when token-specific royalty fee exceeds 100% (10000 basis points).
 * @param _tokenId The token ID with invalid royalty configuration.
 * @param _numerator The fee numerator that exceeds the denominator.
 * @param _denominator The fee denominator (10000 basis points).
 */
error ERC2981InvalidTokenRoyalty(uint256 _tokenId, uint256 _numerator, uint256 _denominator);

/**
 * @notice Thrown when token-specific royalty receiver is the zero address.
 * @param _tokenId The token ID with invalid royalty configuration.
 * @param _receiver The invalid receiver address.
 */
error ERC2981InvalidTokenRoyaltyReceiver(uint256 _tokenId, address _receiver);

bytes32 constant STORAGE_POSITION = keccak256("compose.erc2981");

/**
 * @dev The denominator with which to interpret royalty fees as a percentage of sale price.
 *      Expressed in basis points where 10000 = 100%. This value aligns with the ERC-2981
 *      specification and marketplace expectations. Implemented as a constant for gas efficiency
 *      rather than the virtual function pattern, as Compose does not support inheritance-based
 *      customization. To modify this value, deploy a custom facet implementation.
 */
uint96 constant FEE_DENOMINATOR = 10000;

/**
 * @notice Structure containing royalty information.
 * @param receiver The address that will receive royalty payments.
 * @param royaltyFraction The royalty fee expressed in basis points.
 */
struct RoyaltyInfo {
    address receiver;
    uint96 royaltyFraction;
}

/**
 * @custom:storage-location erc8042:compose.erc2981
 */
struct RoyaltyStorage {
    RoyaltyInfo defaultRoyaltyInfo;
    mapping(uint256 tokenId => RoyaltyInfo) tokenRoyaltyInfo;
}

/**
 * @notice Returns the royalty storage struct from its predefined slot.
 * @dev Uses inline assembly to access diamond storage location.
 * @return s The storage reference for royalty state variables.
 */
function getStorage() pure returns (RoyaltyStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Queries royalty information for a given token and sale price.
 * @dev Returns token-specific royalty or falls back to default royalty.
 *      Royalty amount is calculated as a percentage of the sale price using basis points.
 *      Implements the ERC-2981 royaltyInfo function logic.
 * @param _tokenId The NFT asset queried for royalty information.
 * @param _salePrice The sale price of the NFT asset.
 * @return receiver The address designated to receive the royalty payment.
 * @return royaltyAmount The royalty payment amount for _salePrice.
 */
function royaltyInfo(uint256 _tokenId, uint256 _salePrice) view returns (address receiver, uint256 royaltyAmount) {
    RoyaltyStorage storage s = getStorage();
    RoyaltyInfo memory royalty = s.tokenRoyaltyInfo[_tokenId];

    if (royalty.receiver == address(0)) {
        royalty = s.defaultRoyaltyInfo;
    }

    receiver = royalty.receiver;
    royaltyAmount = (_salePrice * royalty.royaltyFraction) / FEE_DENOMINATOR;
}

/**
 * @notice Sets the default royalty information that applies to all tokens.
 * @dev Validates receiver and fee, then updates default royalty storage.
 * @param _receiver The royalty recipient address.
 * @param _feeNumerator The royalty fee in basis points.
 */
function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) {
    if (_feeNumerator > FEE_DENOMINATOR) {
        revert ERC2981InvalidDefaultRoyalty(_feeNumerator, FEE_DENOMINATOR);
    }
    if (_receiver == address(0)) {
        revert ERC2981InvalidDefaultRoyaltyReceiver(address(0));
    }

    RoyaltyStorage storage s = getStorage();
    s.defaultRoyaltyInfo = RoyaltyInfo(_receiver, _feeNumerator);
}

/**
 * @notice Removes default royalty information.
 * @dev After calling this function, royaltyInfo will return (address(0), 0) for tokens without specific royalty.
 */
function deleteDefaultRoyalty() {
    RoyaltyStorage storage s = getStorage();
    delete s.defaultRoyaltyInfo;
}

/**
 * @notice Sets royalty information for a specific token, overriding the default.
 * @dev Validates receiver and fee, then updates token-specific royalty storage.
 * @param _tokenId The token ID to configure royalty for.
 * @param _receiver The royalty recipient address.
 * @param _feeNumerator The royalty fee in basis points.
 */
function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) {
    if (_feeNumerator > FEE_DENOMINATOR) {
        revert ERC2981InvalidTokenRoyalty(_tokenId, _feeNumerator, FEE_DENOMINATOR);
    }
    if (_receiver == address(0)) {
        revert ERC2981InvalidTokenRoyaltyReceiver(_tokenId, address(0));
    }

    RoyaltyStorage storage s = getStorage();
    s.tokenRoyaltyInfo[_tokenId] = RoyaltyInfo(_receiver, _feeNumerator);
}

/**
 * @notice Resets royalty information for a specific token to use the default setting.
 * @dev Clears token-specific royalty storage, causing fallback to default royalty.
 * @param _tokenId The token ID to reset royalty configuration for.
 */
function resetTokenRoyalty(uint256 _tokenId) {
    RoyaltyStorage storage s = getStorage();
    delete s.tokenRoyaltyInfo[_tokenId];
}
