// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/token/ERC4626/Withdraw/ERC4626WithdrawMod.sol" as ERC4626WithdrawMod;

contract ERC4626WithdrawModHarness {
    function maxWithdraw(address owner) external view returns (uint256) {
        return ERC4626WithdrawMod.maxWithdraw(owner);
    }

    function previewWithdraw(uint256 amount) external view returns (uint256) {
        return ERC4626WithdrawMod.previewWithdraw(amount);
    }

    function withdraw(uint256 amount, address receiver, address owner) external returns (uint256) {
        return ERC4626WithdrawMod.withdraw(amount, receiver, owner);
    }
}
