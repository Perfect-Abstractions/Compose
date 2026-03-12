// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Enumerable/Burn/ERC721EnumerableBurnMod.sol" as ERC721EnumerableBurnMod;

/**
 * @title ERC721EnumerableBurnModHarness
 * @notice Test harness that exposes ERC721EnumerableBurnMod functions as external
 */
contract ERC721EnumerableBurnModHarness {
    function burn(uint256 _tokenId) external {
        ERC721EnumerableBurnMod.burn(_tokenId);
    }
}

