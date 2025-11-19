// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title LibNonReentrancy - Non-Reentrancy Library
/// @notice Provides common non-reentrant functions for Solidity contracts.
library LibNonReentrancy {
    bytes32 constant NON_REENTRANT_SLOT = keccak256("compose.nonreentrant");

    // Function selector - 0x43a0d067
    error Reentrancy();

    /// @dev How to use as a library in user facets
    /*
    function someFunction() external {
        LibNonReentrancy.enter();
        // functions logic here...
        LibNonReentrancy.exit();
    }
    */

    /// @dev How to use as a modifier in user facets
    /*
    modifier nonReentrant {
        LibNonReentrancy.enter();
        _;
        LibNonReentrancy.exit();
    }
    */

    /// @dev This unlocks the entry into a function
    function enter() internal {
        bytes32 position = NON_REENTRANT_SLOT;
        assembly ("memory-safe") {
            if tload(position) {
                mstore(0x00, 0x43a0d067)
                revert(0x00, 0x04)
            }
            tstore(position, 1)
        }
    }

    /// @dev This locks the entry into a function
    function exit() internal {
        bytes32 position = NON_REENTRANT_SLOT;
        assembly {
            tstore(position, 0)
        }
    }
}
