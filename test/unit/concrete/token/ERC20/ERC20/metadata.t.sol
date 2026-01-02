// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20Harness} from "test/harnesses/token/ERC20/ERC20/ERC20Harness.sol";

import "src/token/ERC20/ERC20/ERC20Mod.sol" as ERC20Mod;

contract Metadata_ERC20Mod_Concrete_Unit_Test is Base_Test {
    ERC20Harness internal harness;

    function setUp() public override {
        Base_Test.setUp();

        harness = new ERC20Harness();
        harness.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    function test_Name() external view {
        assertEq(harness.name(), "Test Token");
    }

    function test_Symbol() external view {
        assertEq(harness.symbol(), "TEST");
    }

    function test_Decimals() external view {
        assertEq(harness.decimals(), 18);
    }

    function test_InitialTotalSupply() external view {
        assertEq(harness.totalSupply(), 0);
    }
}
