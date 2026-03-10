// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC1155/Mint/ERC1155MintMod.sol" as ERC1155MintMod;

/**
 * @title ERC1155MintModHarness
 * @notice Test harness that exposes ERC1155MintMod functions as external
 */
contract ERC1155MintModHarness {
    function mint(address _to, uint256 _id, uint256 _value, bytes memory _data) external {
        ERC1155MintMod.mint(_to, _id, _value, _data);
    }

    function mintBatch(address _to, uint256[] memory _ids, uint256[] memory _values, bytes memory _data) external {
        ERC1155MintMod.mintBatch(_to, _ids, _values, _data);
    }
}
