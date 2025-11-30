// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {OwnerTwoStepsFacet} from "../../../../src/access/OwnerTwoSteps/OwnerTwoStepsFacet.sol";

/**
 * @title OwnerTwoStepsFacet Test Harness
 * @notice Extends OwnerTwoStepsFacet with initialization and test-specific functions
 */
contract OwnerTwoStepsFacetHarness is OwnerTwoStepsFacet {
    /**
     * @notice Initialize the owner for testing
     * @dev This function is only for testing purposes
     */
    function initialize(address _owner) external {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
        ownerStorage.owner = _owner;
        pendingStorage.pendingOwner = address(0);
    }

    /**
     * @notice Force set owner without any checks (for testing edge cases)
     * @dev This bypasses all access control for testing purposes
     */
    function forceSetOwner(address _owner) external {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        ownerStorage.owner = _owner;
    }

    /**
     * @notice Force set pending owner without any checks (for testing edge cases)
     * @dev This bypasses all access control for testing purposes
     */
    function forceSetPendingOwner(address _pendingOwner) external {
        PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
        pendingStorage.pendingOwner = _pendingOwner;
    }

    /**
     * @notice Get the raw storage values (for testing storage consistency)
     */
    function getStorageValues() external view returns (address currentOwner, address currentPendingOwner) {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
        currentOwner = ownerStorage.owner;
        currentPendingOwner = pendingStorage.pendingOwner;
    }

    /**
     * @notice Force renounce ownership (for testing renounced state)
     */
    function forceRenounce() external {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
        ownerStorage.owner = address(0);
        pendingStorage.pendingOwner = address(0);
    }
}
