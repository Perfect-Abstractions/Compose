// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/access/Owner/OwnerMod.sol" as Owner;

/**
 * @title LibOwner Test Harness
 * @notice Exposes internal LibOwner functions as external for testing
 */
contract OwnerHarness {
    /**
     * @notice Initialize the owner (for testing)
     */
    function initialize(address _owner) external {
        Owner.OwnerStorage storage s = Owner.getStorage();
        s.owner = _owner;
    }

    /**
     * @notice Get the current owner
     */
    function owner() external view returns (address) {
        return Owner.owner();
    }

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address _newOwner) external {
        Owner.transferOwnership(_newOwner);
    }

    /**
     * @notice Check if caller is owner (new function added by maintainer)
     */
    function requireOwner() external view {
        Owner.requireOwner();
    }

    /**
     * @notice Get storage directly (for testing storage consistency)
     */
    function getStorageOwner() external view returns (address) {
        return Owner.getStorage().owner;
    }

    /**
     * @notice Force set owner to zero without checks (for testing renounced state)
     */
    function forceRenounce() external {
        Owner.OwnerStorage storage s = Owner.getStorage();
        s.owner = address(0);
    }
}
