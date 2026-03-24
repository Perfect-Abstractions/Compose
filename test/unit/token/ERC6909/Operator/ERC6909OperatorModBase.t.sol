// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909OperatorModHarness} from "test/utils/harnesses/token/ERC6909/ERC6909OperatorModHarness.sol";

import {ERC6909_Test_Base} from "test/unit/token/ERC6909/ERC6909TestBase.sol";

abstract contract ERC6909OperatorMod_Base_Test is ERC6909_Test_Base {
    ERC6909OperatorModHarness internal harness;

    function setUp() public virtual override {
        ERC6909_Test_Base.setUp();
        harness = new ERC6909OperatorModHarness();
        vm.label(address(harness), "ERC6909OperatorModHarness");
    }
}
