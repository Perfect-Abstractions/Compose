// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    transfer as erc6909Transfer,
    transferFrom as erc6909TransferFrom
} from "src/token/ERC6909/Transfer/ERC6909TransferMod.sol";

/**
 * @notice Exposes ERC6909TransferMod functions for tests.
 */
contract ERC6909TransferModHarness {
    function transfer(address receiver, uint256 id, uint256 amount) external {
        erc6909Transfer(receiver, id, amount);
    }

    function transferFrom(address sender, address receiver, uint256 id, uint256 amount) external {
        erc6909TransferFrom(sender, receiver, id, amount);
    }
}
