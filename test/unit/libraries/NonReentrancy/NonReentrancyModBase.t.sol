// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {NonReentrantHarness} from "test/utils/harnesses/libraries/NonReentrancyHarness.sol";

contract NonReentrancyMod_Base_Test is Base_Test {
    NonReentrantHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new NonReentrantHarness();
    }
}

