// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909ApproveModHarness} from "test/utils/harnesses/token/ERC6909/ERC6909ApproveModHarness.sol";

import {ERC6909_Test_Base} from "test/unit/token/ERC6909/ERC6909TestBase.sol";

abstract contract ERC6909ApproveMod_Base_Test is ERC6909_Test_Base {
    ERC6909ApproveModHarness internal harness;

    function setUp() public virtual override {
        ERC6909_Test_Base.setUp();
        harness = new ERC6909ApproveModHarness();
        vm.label(address(harness), "ERC6909ApproveModHarness");
    }
}
