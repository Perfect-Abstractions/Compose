// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/libraries/NonReentrancyMod.sol" as NonReentrancyMod;

contract NonReentrantHarness {
    error ForcedFailure();

    uint256 public counter;

    function guardedIncrement() public {
        NonReentrancyMod.enter();
        counter++;
        NonReentrancyMod.exit();
    }

    function guardedIncrementAndReenter() external {
        NonReentrancyMod.enter();
        counter++;

        this.guardedIncrement();

        NonReentrancyMod.exit();
    }

    function guardedIncrementAndForceRevert() external {
        NonReentrancyMod.enter();
        counter++;
        revert ForcedFailure();
    }
}
