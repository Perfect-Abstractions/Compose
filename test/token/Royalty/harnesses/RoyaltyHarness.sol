// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/token/Royalty/RoyaltyMod.sol" as Royalty;

/**
 * @title RoyaltyHarness
 * @notice Test harness that exposes LibRoyalty's internal functions as external
 * @dev Required for testing since LibRoyalty only has internal functions
 */
contract RoyaltyHarness {
    /**
     * @notice Exposes Royalty.royaltyInfo as an external function
     */
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return Royalty.royaltyInfo(_tokenId, _salePrice);
    }

    /**
     * @notice Exposes Royalty.setDefaultRoyalty as an external function
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external {
        Royalty.setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Exposes Royalty.deleteDefaultRoyalty as an external function
     */
    function deleteDefaultRoyalty() external {
        Royalty.deleteDefaultRoyalty();
    }

    /**
     * @notice Exposes Royalty.setTokenRoyalty as an external function
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external {
        Royalty.setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /**
     * @notice Exposes Royalty.resetTokenRoyalty as an external function
     */
    function resetTokenRoyalty(uint256 _tokenId) external {
        Royalty.resetTokenRoyalty(_tokenId);
    }

    /**
     * @notice Get default royalty receiver for testing
     */
    function getDefaultRoyaltyReceiver() external view returns (address) {
        return Royalty.getStorage().defaultRoyaltyInfo.receiver;
    }

    /**
     * @notice Get default royalty fraction for testing
     */
    function getDefaultRoyaltyFraction() external view returns (uint96) {
        return Royalty.getStorage().defaultRoyaltyInfo.royaltyFraction;
    }

    /**
     * @notice Get token-specific royalty receiver for testing
     */
    function getTokenRoyaltyReceiver(uint256 _tokenId) external view returns (address) {
        return Royalty.getStorage().tokenRoyaltyInfo[_tokenId].receiver;
    }

    /**
     * @notice Get token-specific royalty fraction for testing
     */
    function getTokenRoyaltyFraction(uint256 _tokenId) external view returns (uint96) {
        return Royalty.getStorage().tokenRoyaltyInfo[_tokenId].royaltyFraction;
    }
}
