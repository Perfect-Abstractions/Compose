// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibRoyalty} from "../../../../src/token/Royalty/LibRoyalty.sol";

/// @title LibRoyaltyHarness
/// @notice Test harness that exposes LibRoyalty's internal functions as external
/// @dev Required for testing since LibRoyalty only has internal functions
contract LibRoyaltyHarness {
    /// @notice Exposes LibRoyalty.royaltyInfo as an external function
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount)
    {
        return LibRoyalty.royaltyInfo(_tokenId, _salePrice);
    }

    /// @notice Exposes LibRoyalty.setDefaultRoyalty as an external function
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external {
        LibRoyalty.setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /// @notice Exposes LibRoyalty.deleteDefaultRoyalty as an external function
    function deleteDefaultRoyalty() external {
        LibRoyalty.deleteDefaultRoyalty();
    }

    /// @notice Exposes LibRoyalty.setTokenRoyalty as an external function
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external {
        LibRoyalty.setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /// @notice Exposes LibRoyalty.resetTokenRoyalty as an external function
    function resetTokenRoyalty(uint256 _tokenId) external {
        LibRoyalty.resetTokenRoyalty(_tokenId);
    }

    /// @notice Get default royalty receiver for testing
    function getDefaultRoyaltyReceiver() external view returns (address) {
        return LibRoyalty.getStorage().defaultRoyaltyInfo.receiver;
    }

    /// @notice Get default royalty fraction for testing
    function getDefaultRoyaltyFraction() external view returns (uint96) {
        return LibRoyalty.getStorage().defaultRoyaltyInfo.royaltyFraction;
    }

    /// @notice Get token-specific royalty receiver for testing
    function getTokenRoyaltyReceiver(uint256 _tokenId) external view returns (address) {
        return LibRoyalty.getStorage().tokenRoyaltyInfo[_tokenId].receiver;
    }

    /// @notice Get token-specific royalty fraction for testing
    function getTokenRoyaltyFraction(uint256 _tokenId) external view returns (uint96) {
        return LibRoyalty.getStorage().tokenRoyaltyInfo[_tokenId].royaltyFraction;
    }
}

