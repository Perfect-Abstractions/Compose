// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/Data/ERC4626DataMod.sol" as ERC4626DataMod;

contract ERC4626DataModHarness {
    function asset() external view returns (address) {
        return ERC4626DataMod.asset();
    }

    function totalAssets() external view returns (uint256) {
        return ERC4626DataMod.totalAssets();
    }
}
