// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {mint as erc6909Mint} from "src/token/ERC6909/Mint/ERC6909MintMod.sol";

/**
 * @notice Exposes ERC6909MintMod `mint` for tests.
 */
contract ERC6909MintModHarness {
    function mint(address account, uint256 id, uint256 value) external {
        erc6909Mint(account, id, value);
    }
}
