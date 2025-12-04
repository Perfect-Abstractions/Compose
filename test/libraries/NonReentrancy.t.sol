// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import "src/libraries/NonReentrancyMod.sol" as NonReentrancyMod;
import {NonReentrantHarness} from "test/libraries/harnesses/NonReentrancyHarness.sol";

contract LibNonReentrancyTest is Test {
    NonReentrantHarness internal harness;

    function setUp() public {
        harness = new NonReentrantHarness();
    }

    function test_GuardedIncrement_IncrementsCounter() public {
        harness.guardedIncrement();
        assertEq(harness.counter(), 1);
    }

    function test_GuardedIncrement_AllowsSequentialCalls() public {
        harness.guardedIncrement();
        harness.guardedIncrement();
        assertEq(harness.counter(), 2);
    }

    function test_RevertWhen_ReenteringFunction() public {
        vm.expectRevert(NonReentrancyMod.Reentrancy.selector);
        harness.guardedIncrementAndReenter();
    }

    function test_GuardResetsAfterRevert() public {
        vm.expectRevert(NonReentrantHarness.ForcedFailure.selector);
        harness.guardedIncrementAndForceRevert();

        harness.guardedIncrement();
        assertEq(harness.counter(), 1);
    }
}
