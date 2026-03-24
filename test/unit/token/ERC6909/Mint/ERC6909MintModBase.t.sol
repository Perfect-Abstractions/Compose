// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909MintModHarness} from "test/utils/harnesses/token/ERC6909/ERC6909MintModHarness.sol";

import {ERC6909_Test_Base} from "test/unit/token/ERC6909/ERC6909TestBase.sol";

abstract contract ERC6909MintMod_Base_Test is ERC6909_Test_Base {
    ERC6909MintModHarness internal harness;

    function setUp() public virtual override {
        ERC6909_Test_Base.setUp();
        harness = new ERC6909MintModHarness();
        vm.label(address(harness), "ERC6909MintModHarness");
    }
}
