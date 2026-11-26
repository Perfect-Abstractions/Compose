// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/Deposit/ERC4626DepositMod.sol" as ERC4626DepositMod;

contract ERC4626DepositModHarness {
    function maxDeposit(address owner) external pure returns (uint256) {
        return ERC4626DepositMod.maxDeposit(owner);
    }

    function previewDeposit(uint256 amount) external view returns (uint256) {
        return ERC4626DepositMod.previewDeposit(amount);
    }

    function deposit(uint256 amount, address receiver) external returns (uint256) {
        return ERC4626DepositMod.deposit(amount, receiver);
    }
}
