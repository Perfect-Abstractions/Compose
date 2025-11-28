// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {LibOwner} from "../../../../src/access/Owner/LibOwner.sol";

/**
 * @title LibOwner Test Harness
 * @notice Exposes internal LibOwner functions as external for testing
 */
contract LibOwnerHarness {
    /**
     * @notice Initialize the owner (for testing)
     */
    function initialize(address _owner) external {
        LibOwner.OwnerStorage storage s = LibOwner.getStorage();
        s.owner = _owner;
    }

    /**
     * @notice Get the current owner
     */
    function owner() external view returns (address) {
        return LibOwner.owner();
    }

    /**
     * @notice Transfer ownership
     */
    function transferOwnership(address _newOwner) external {
        LibOwner.transferOwnership(_newOwner);
    }

    /**
     * @notice Check if caller is owner (new function added by maintainer)
     */
    function requireOwner() external view {
        LibOwner.requireOwner();
    }

    /**
     * @notice Get storage directly (for testing storage consistency)
     */
    function getStorageOwner() external view returns (address) {
        return LibOwner.getStorage().owner;
    }

    /**
     * @notice Force set owner to zero without checks (for testing renounced state)
     */
    function forceRenounce() external {
        LibOwner.OwnerStorage storage s = LibOwner.getStorage();
        s.owner = address(0);
    }
}
