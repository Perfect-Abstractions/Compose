// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "../../../../src/access/Owner/OwnerMod.sol" as OwnerMod;

/**
 * @title LibOwner Test Harness
 * @notice Exposes internal LibOwner functions as external for testing
 */
contract OwnerHarness {
    /**
     * @notice Initialize the owner (for testing)
     */
    function initialize(address _owner) external {
        OwnerMod.OwnerStorage storage s = OwnerMod.getStorage();
        s.owner = _owner;
    }

    /**
     * @notice Get the current owner
     */
    function owner() external view returns (address) {
        return OwnerMod.owner();
    }

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address _newOwner) external {
        OwnerMod.transferOwnership(_newOwner);
    }

    /**
     * @notice Check if caller is owner (new function added by maintainer)
     */
    function requireOwner() external view {
        OwnerMod.requireOwner();
    }

    /**
     * @notice Get storage directly (for testing storage consistency)
     */
    function getStorageOwner() external view returns (address) {
        return OwnerMod.getStorage().owner;
    }

    /**
     * @notice Force set owner to zero without checks (for testing renounced state)
     */
    function forceRenounce() external {
        OwnerMod.OwnerStorage storage s = OwnerMod.getStorage();
        s.owner = address(0);
    }
}
