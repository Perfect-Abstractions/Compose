// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-173 Two-Step Ownership Data Module
 * @notice Provides data for two-step ownership transfer
 */

bytes32 constant STORAGE_POSITION = keccak256("erc173.owner.pending");

/**
 * @custom:storage-location erc8042:erc173.owner.pending
 */
struct PendingOwnerStorage {
    address pendingOwner;
}

/**
 * @notice Returns a pointer to the PendingOwner storage struct.
 * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
 * @return s The PendingOwnerStorage struct in storage.
 */
function getStorage() pure returns (PendingOwnerStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Get the address of the pending owner
 * @return The address of the pending owner.
 */
function pendingOwner() view returns (address) {
    return getStorage().pendingOwner;
}
