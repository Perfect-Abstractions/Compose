// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibOwnerTwoSteps} from "../../../../src/access/OwnerTwoSteps/LibOwnerTwoSteps.sol";

/// @title LibOwnerTwoSteps Test Harness
/// @notice Exposes internal LibOwnerTwoSteps functions as external for testing
contract LibOwnerTwoStepsHarness {
    using LibOwnerTwoSteps for LibOwnerTwoSteps.OwnerTwoStepsStorage;

    /// @notice Initialize the owner (for testing)
    function initialize(address _owner) external {
        LibOwnerTwoSteps.OwnerTwoStepsStorage storage s = LibOwnerTwoSteps.getStorage();
        s.owner = _owner;
        s.pendingOwner = address(0);
    }

    /// @notice Get the current owner
    function owner() external view returns (address) {
        return LibOwnerTwoSteps.owner();
    }

    /// @notice Get the pending owner
    function pendingOwner() external view returns (address) {
        return LibOwnerTwoSteps.pendingOwner();
    }

    /// @notice Initiate ownership transfer
    function transferOwnership(address _newOwner) external {
        LibOwnerTwoSteps.transferOwnership(_newOwner);
    }

    /// @notice Accept ownership transfer
    function acceptOwnership() external {
        LibOwnerTwoSteps.acceptOwnership();
    }

    /// @notice Renounce ownership (new function added by maintainer)
    function renounceOwnership() external {
        LibOwnerTwoSteps.renounceOwnership();
    }

    /// @notice Check if caller is owner (new function added by maintainer)
    function requireOwner() external view {
        LibOwnerTwoSteps.requireOwner();
    }

    /// @notice Get storage directly (for testing storage consistency)
    function getStorageOwner() external view returns (address) {
        return LibOwnerTwoSteps.getStorage().owner;
    }

    /// @notice Get storage pending owner directly (for testing storage consistency)
    function getStoragePendingOwner() external view returns (address) {
        return LibOwnerTwoSteps.getStorage().pendingOwner;
    }

    /// @notice Force set owner to zero without checks (for testing renounced state)
    function forceRenounce() external {
        LibOwnerTwoSteps.OwnerTwoStepsStorage storage s = LibOwnerTwoSteps.getStorage();
        s.owner = address(0);
        s.pendingOwner = address(0);
    }

    /// @notice Force set pending owner (for testing edge cases)
    function forcePendingOwner(address _pendingOwner) external {
        LibOwnerTwoSteps.OwnerTwoStepsStorage storage s = LibOwnerTwoSteps.getStorage();
        s.pendingOwner = _pendingOwner;
    }
}
