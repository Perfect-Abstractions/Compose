// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Enumerable/Mint/ERC721EnumerableMintMod.sol" as ERC721EnumerableMintMod;

/**
 * @title ERC721EnumerableMintModHarness
 * @notice Test harness that exposes ERC721EnumerableMintMod functions as external
 */
contract ERC721EnumerableMintModHarness {
    function mint(address _to, uint256 _tokenId) external {
        ERC721EnumerableMintMod.mint(_to, _tokenId);
    }
}

