// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/Mint/ERC4626MintMod.sol" as ERC4626MintMod;

contract ERC4626MintModHarness {
    function maxMint(address owner) external pure returns (uint256) {
        return ERC4626MintMod.maxMint(owner);
    }

    function previewMint(uint256 amount) external view returns (uint256) {
        return ERC4626MintMod.previewMint(amount);
    }

    function mint(uint256 amount, address receiver) external returns (uint256) {
        return ERC4626MintMod.mint(amount, receiver);
    }
}
