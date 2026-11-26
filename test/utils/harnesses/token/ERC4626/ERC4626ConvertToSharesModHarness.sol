// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/ConvertToShares/ERC4626ConvertToSharesMod.sol" as ERC4626ConvertToSharesMod;

contract ERC4626ConvertToSharesModHarness {
    function convertToShares(uint256 amount) external view returns (uint256) {
        return ERC4626ConvertToSharesMod.convertToShares(amount);
    }
}
