// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {NonReentrancyMod_Base_Test} from "test/unit/libraries/NonReentrancy/NonReentrancyModBase.t.sol";
import "src/libraries/NonReentrancyMod.sol" as NonReentrancyMod;
import {NonReentrantHarness} from "test/utils/harnesses/libraries/NonReentrancyHarness.sol";

/**
 *  @dev BTT spec: test/trees/NonReentrancy.tree
 */
contract NonReentrancyMod_Fuzz_Unit_Test is NonReentrancyMod_Base_Test {
    function test_ShouldIncrementCounter_WhenGuardedIncrementCalledOnce() public {
        harness.guardedIncrement();
        assertEq(harness.counter(), 1);
    }

    function test_ShouldIncrementCounter_WhenGuardedIncrementCalledTwiceSequentially() public {
        harness.guardedIncrement();
        harness.guardedIncrement();
        assertEq(harness.counter(), 2);
    }

    function test_ShouldRevert_WhenReenteringGuardedFunction() public {
        vm.expectRevert(NonReentrancyMod.Reentrancy.selector);
        harness.guardedIncrementAndReenter();
    }

    function test_ShouldAllowGuardedCallsAfterRevert() public {
        vm.expectRevert(NonReentrantHarness.ForcedFailure.selector);
        harness.guardedIncrementAndForceRevert();

        harness.guardedIncrement();
        assertEq(harness.counter(), 1);
    }
}

