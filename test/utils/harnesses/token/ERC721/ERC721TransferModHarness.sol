// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Transfer/ERC721TransferMod.sol" as ERC721TransferMod;

/**
 * @title ERC721TransferModHarness
 * @notice Test harness that exposes ERC721TransferMod functions as external
 */
contract ERC721TransferModHarness {
    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        ERC721TransferMod.transferFrom(_from, _to, _tokenId);
    }
}

