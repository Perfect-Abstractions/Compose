// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC721/Approve/ERC721ApproveMod.sol" as ERC721ApproveMod;

/**
 * @title ERC721ApproveModHarness
 * @notice Test harness that exposes ERC721ApproveMod functions as external
 */
contract ERC721ApproveModHarness {
    /**
     * @notice Exposes ERC721ApproveMod.approve as an external function
     */
    function approve(address _to, uint256 _tokenId) external {
        ERC721ApproveMod.approve(_to, _tokenId);
    }

    /**
     * @notice Exposes ERC721ApproveMod.setApprovalForAll as an external function
     */
    function setApprovalForAll(address _user, address _operator, bool _approved) external {
        ERC721ApproveMod.setApprovalForAll(_user, _operator, _approved);
    }
}

