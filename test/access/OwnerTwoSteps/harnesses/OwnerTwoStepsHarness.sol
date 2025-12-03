// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/access/OwnerTwoSteps/OwnerTwoSteps.sol" as OwnerTwoSteps;

/**
 * @title LibOwnerTwoSteps Test Harness
 * @notice Exposes internal LibOwnerTwoSteps functions as external for testing
 */
contract OwnerTwoStepsHarness {
    /**
     * @notice Initialize the owner (for testing)
     */
    function initialize(address _owner) external {
        OwnerTwoSteps.OwnerStorage storage ownerStorage = OwnerTwoSteps.getOwnerStorage();
        OwnerTwoSteps.PendingOwnerStorage storage pendingStorage = OwnerTwoSteps.getPendingOwnerStorage();
        ownerStorage.owner = _owner;
        pendingStorage.pendingOwner = address(0);
    }

    /**
     * @notice Get the current owner
     */
    function owner() external view returns (address) {
        return OwnerTwoSteps.owner();
    }

    /**
     * @notice Get the pending owner
     */
    function pendingOwner() external view returns (address) {
        return OwnerTwoSteps.pendingOwner();
    }

    /**
     * @notice Initiate ownership transfer
     */
    function transferOwnership(address _newOwner) external {
        OwnerTwoSteps.transferOwnership(_newOwner);
    }

    /**
     * @notice Accept ownership transfer
     */
    function acceptOwnership() external {
        OwnerTwoSteps.acceptOwnership();
    }

    /**
     * @notice Renounce ownership (new function added by maintainer)
     */
    function renounceOwnership() external {
        OwnerTwoSteps.renounceOwnership();
    }

    /**
     * @notice Check if caller is owner (new function added by maintainer)
     */
    function requireOwner() external view {
        OwnerTwoSteps.requireOwner();
    }

    /**
     * @notice Get storage directly (for testing storage consistency)
     */
    function getStorageOwner() external view returns (address) {
        return OwnerTwoSteps.getOwnerStorage().owner;
    }

    /**
     * @notice Get storage pending owner directly (for testing storage consistency)
     */
    function getStoragePendingOwner() external view returns (address) {
        return OwnerTwoSteps.getPendingOwnerStorage().pendingOwner;
    }

    /**
     * @notice Force set owner to zero without checks (for testing renounced state)
     */
    function forceRenounce() external {
        OwnerTwoSteps.OwnerStorage storage ownerStorage = OwnerTwoSteps.getOwnerStorage();
        OwnerTwoSteps.PendingOwnerStorage storage pendingStorage = OwnerTwoSteps.getPendingOwnerStorage();
        ownerStorage.owner = address(0);
        pendingStorage.pendingOwner = address(0);
    }

    /**
     * @notice Force set pending owner (for testing edge cases)
     */
    function forcePendingOwner(address _pendingOwner) external {
        OwnerTwoSteps.PendingOwnerStorage storage pendingStorage = OwnerTwoSteps.getPendingOwnerStorage();
        pendingStorage.pendingOwner = _pendingOwner;
    }
}
