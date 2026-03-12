// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Burn/ERC721BurnMod.sol" as ERC721BurnMod;

/**
 * @title ERC721BurnModHarness
 * @notice Test harness that exposes ERC721BurnMod functions as external
 */
contract ERC721BurnModHarness {
    function burn(uint256 _tokenId) external {
        ERC721BurnMod.burn(_tokenId);
    }
}

