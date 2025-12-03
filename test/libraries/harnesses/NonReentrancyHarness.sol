// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "src/libraries/NonReentrancy.sol" as NonReentrancy;

contract NonReentrantHarness {
    error ForcedFailure();

    uint256 public counter;

    function guardedIncrement() public {
        NonReentrancy.enter();
        counter++;
        NonReentrancy.exit();
    }

    function guardedIncrementAndReenter() external {
        NonReentrancy.enter();
        counter++;

        this.guardedIncrement();

        NonReentrancy.exit();
    }

    function guardedIncrementAndForceRevert() external {
        NonReentrancy.enter();
        counter++;
        revert ForcedFailure();
    }
}
