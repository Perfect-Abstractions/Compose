// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Mint/ERC721MintMod.sol" as ERC721MintMod;

/**
 * @title ERC721MintModHarness
 * @notice Test harness that exposes ERC721MintMod functions as external
 */
contract ERC721MintModHarness {
    /**
     * @notice Exposes ERC721MintMod.mintERC721 as an external function
     */
    function mint(address _to, uint256 _tokenId) external {
        ERC721MintMod.mintERC721(_to, _tokenId);
    }
}
