// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    crosschainMint as _crosschainMint,
    crosschainBurn as _crosschainBurn,
    checkTokenBridge as _checkTokenBridge
} from "src/token/ERC20/Bridgeable/ERC20BridgeableMod.sol";

contract ERC20BridgeableModHarness {
    function crosschainMint(address account, uint256 value) external {
        _crosschainMint(account, value);
    }

    function crosschainBurn(address from, uint256 value) external {
        _crosschainBurn(from, value);
    }

    function checkTokenBridge(address caller) external view {
        _checkTokenBridge(caller);
    }
}
