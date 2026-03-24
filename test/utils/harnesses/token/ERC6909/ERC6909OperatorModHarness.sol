// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {setOperator as erc6909SetOperator} from "src/token/ERC6909/Operator/ERC6909OperatorMod.sol";

/**
 * @notice Exposes ERC6909OperatorMod `setOperator` for tests.
 */
contract ERC6909OperatorModHarness {
    function setOperator(address spender, bool approved) external {
        erc6909SetOperator(spender, approved);
    }
}
