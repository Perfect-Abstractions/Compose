// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {burn as erc6909Burn, burnFrom as erc6909BurnFrom} from "src/token/ERC6909/Burn/ERC6909BurnMod.sol";

/**
 * @notice Exposes ERC6909BurnMod burn functions for tests.
 */
contract ERC6909BurnModHarness {
    function burn(uint256 id, uint256 amount) external {
        erc6909Burn(id, amount);
    }

    function burnFrom(address from, uint256 id, uint256 amount) external {
        erc6909BurnFrom(from, id, amount);
    }
}
