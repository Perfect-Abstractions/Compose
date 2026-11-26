// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/Redeem/ERC4626RedeemMod.sol" as ERC4626RedeemMod;

contract ERC4626RedeemModHarness {
    function maxRedeem(address owner) external view returns (uint256) {
        return ERC4626RedeemMod.maxRedeem(owner);
    }

    function previewRedeem(uint256 amount) external view returns (uint256) {
        return ERC4626RedeemMod.previewRedeem(amount);
    }

    function redeem(uint256 amount, address receiver, address owner) external returns (uint256) {
        return ERC4626RedeemMod.redeem(amount, receiver, owner);
    }
}
