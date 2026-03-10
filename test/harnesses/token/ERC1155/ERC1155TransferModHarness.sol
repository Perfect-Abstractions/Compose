// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC1155/Transfer/ERC1155TransferMod.sol" as ERC1155TransferMod;

/**
 * @title ERC1155TransferModHarness
 * @notice Test harness that exposes ERC1155TransferMod functions as external
 */
contract ERC1155TransferModHarness {
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, address _operator) external {
        ERC1155TransferMod.safeTransferFrom(_from, _to, _id, _value, _operator);
    }

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _values,
        address _operator
    ) external {
        ERC1155TransferMod.safeBatchTransferFrom(_from, _to, _ids, _values, _operator);
    }
}
