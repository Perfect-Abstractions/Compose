// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import * as LibNonReentrancy from "src/libraries/LibNonReentrancy.sol";

contract NonReentrantHarness {
    error ForcedFailure();

    uint256 public counter;

    function guardedIncrement() public {
        LibNonReentrancy.enter();
        counter++;
        LibNonReentrancy.exit();
    }

    function guardedIncrementAndReenter() external {
        LibNonReentrancy.enter();
        counter++;

        this.guardedIncrement();

        LibNonReentrancy.exit();
    }

    function guardedIncrementAndForceRevert() external {
        LibNonReentrancy.enter();
        counter++;
        revert ForcedFailure();
    }
}
