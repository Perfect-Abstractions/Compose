// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC1155/Approve/ERC1155ApproveMod.sol" as ERC1155ApproveMod;

/**
 * @title ERC1155ApproveModHarness
 * @notice Test harness that exposes ERC1155ApproveMod functions as external
 */
contract ERC1155ApproveModHarness {
    function setApprovalForAll(address _user, address _operator, bool _approved) external {
        ERC1155ApproveMod.setApprovalForAll(_user, _operator, _approved);
    }
}
