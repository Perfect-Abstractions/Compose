// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibERC721 as LibERC721Enumerable} from "./LibERC721Enumerable.sol";

/// @title ERC-721 Enumerable Burn Facet
/// @notice Provides an external burn entry point that composes with other ERC-721 enumerable facets.
/// @dev Keeps burn logic isolated so diamonds can opt-in without inheriting unrelated functionality.
contract ERC721EnumerableBurnFacet {
    /// @notice Burns (destroys) a token, removing it from enumeration tracking.
    /// @param _tokenId The ID of the token to burn.
    function burn(uint256 _tokenId) external {
        LibERC721Enumerable.burn(_tokenId, msg.sender);
    }
}
