// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Enumerable/Transfer/ERC721EnumerableTransferMod.sol" as ERC721EnumerableTransferMod;

/**
 * @title ERC721EnumerableTransferModHarness
 * @notice Test harness that exposes ERC721EnumerableTransferMod functions as external
 */
contract ERC721EnumerableTransferModHarness {
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        ERC721EnumerableTransferMod.transferFrom(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external {
        ERC721EnumerableTransferMod.safeTransferFrom(_from, _to, _tokenId);
    }

    function safeTransferFrom(address _from, address _to, uint256 _tokenId, bytes calldata _data) external {
        ERC721EnumerableTransferMod.safeTransferFrom(_from, _to, _tokenId, _data);
    }
}

