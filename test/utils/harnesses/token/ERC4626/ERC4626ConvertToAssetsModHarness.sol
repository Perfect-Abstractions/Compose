// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/ConvertToAssets/ERC4626ConvertToAssetsMod.sol" as ERC4626ConvertToAssetsMod;

contract ERC4626ConvertToAssetsModHarness {
    function convertToAssets(uint256 amount) external view returns (uint256) {
        return ERC4626ConvertToAssetsMod.convertToAssets(amount);
    }
}
