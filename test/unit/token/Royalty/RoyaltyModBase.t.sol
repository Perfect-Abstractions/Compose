// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {RoyaltyHarness} from "test/utils/harnesses/token/Royalty/RoyaltyHarness.sol";

abstract contract RoyaltyMod_Base_Test is Base_Test {
    RoyaltyHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new RoyaltyHarness();
        vm.label(address(harness), "RoyaltyHarness");
    }
}
