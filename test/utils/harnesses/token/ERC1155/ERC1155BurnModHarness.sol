// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC1155/Burn/ERC1155BurnMod.sol" as ERC1155BurnMod;

/**
 * @title ERC1155BurnModHarness
 * @notice Test harness that exposes ERC1155BurnMod functions as external
 */
contract ERC1155BurnModHarness {
    function burn(address _from, uint256 _id, uint256 _value) external {
        ERC1155BurnMod.burn(_from, _id, _value);
    }

    function burnBatch(address _from, uint256[] memory _ids, uint256[] memory _values) external {
        ERC1155BurnMod.burnBatch(_from, _ids, _values);
    }
}
