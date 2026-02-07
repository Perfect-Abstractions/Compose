// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20TransferModHarness} from "test/harnesses/token/ERC20/ERC20TransferModHarness.sol";

contract ERC20TransferMod_Base_Test is Base_Test {
    ERC20TransferModHarness internal harness;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new ERC20TransferModHarness();
        vm.label(address(harness), "ERC20TransferModHarness");
    }
}
