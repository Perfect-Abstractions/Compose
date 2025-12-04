// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/access/OwnerTwoSteps/OwnerTwoStepsMod.sol" as OwnerTwoStepsMod;

/**
 * @title LibOwnerTwoSteps Test Harness
 * @notice Exposes internal LibOwnerTwoSteps functions as external for testing
 */
contract OwnerTwoStepsHarness {
    /**
     * @notice Initialize the owner (for testing)
     */
    function initialize(address _owner) external {
        OwnerTwoStepsMod.OwnerStorage storage ownerStorage = OwnerTwoStepsMod.getOwnerStorage();
        OwnerTwoStepsMod.PendingOwnerStorage storage pendingStorage = OwnerTwoStepsMod.getPendingOwnerStorage();
        ownerStorage.owner = _owner;
        pendingStorage.pendingOwner = address(0);
    }

    /**
     * @notice Get the current owner
     */
    function owner() external view returns (address) {
        return OwnerTwoStepsMod.owner();
    }

    /**
     * @notice Get the pending owner
     */
    function pendingOwner() external view returns (address) {
        return OwnerTwoStepsMod.pendingOwner();
    }

    /**
     * @notice Initiate ownership transfer
     */
    function transferOwnership(address _newOwner) external {
        OwnerTwoStepsMod.transferOwnership(_newOwner);
    }

    /**
     * @notice Accept ownership transfer
     */
    function acceptOwnership() external {
        OwnerTwoStepsMod.acceptOwnership();
    }

    /**
     * @notice Renounce ownership (new function added by maintainer)
     */
    function renounceOwnership() external {
        OwnerTwoStepsMod.renounceOwnership();
    }

    /**
     * @notice Check if caller is owner (new function added by maintainer)
     */
    function requireOwner() external view {
        OwnerTwoStepsMod.requireOwner();
    }

    /**
     * @notice Get storage directly (for testing storage consistency)
     */
    function getStorageOwner() external view returns (address) {
        return OwnerTwoStepsMod.getOwnerStorage().owner;
    }

    /**
     * @notice Get storage pending owner directly (for testing storage consistency)
     */
    function getStoragePendingOwner() external view returns (address) {
        return OwnerTwoStepsMod.getPendingOwnerStorage().pendingOwner;
    }

    /**
     * @notice Force set owner to zero without checks (for testing renounced state)
     */
    function forceRenounce() external {
        OwnerTwoStepsMod.OwnerStorage storage ownerStorage = OwnerTwoStepsMod.getOwnerStorage();
        OwnerTwoStepsMod.PendingOwnerStorage storage pendingStorage = OwnerTwoStepsMod.getPendingOwnerStorage();
        ownerStorage.owner = address(0);
        pendingStorage.pendingOwner = address(0);
    }

    /**
     * @notice Force set pending owner (for testing edge cases)
     */
    function forcePendingOwner(address _pendingOwner) external {
        OwnerTwoStepsMod.PendingOwnerStorage storage pendingStorage = OwnerTwoStepsMod.getPendingOwnerStorage();
        pendingStorage.pendingOwner = _pendingOwner;
    }
}
