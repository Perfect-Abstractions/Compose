// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-173 Two-Step Renounce Ownership Module
 * @notice Provides logic to renounce ownership in a two-step ownership model.
 */

/**
 * @dev This emits when ownership of a contract changes.
 */
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

/*
 * @notice Thrown when a non-owner attempts an action restricted to owner.
 */
error OwnerUnauthorizedAccount();

bytes32 constant OWNER_STORAGE_POSITION = keccak256("erc173.owner");

/**
 * @custom:storage-location erc8042:erc173.owner
 */
struct OwnerStorage {
    address owner;
}

/**
 * @notice Returns a pointer to the ERC-173 storage struct.
 * @dev Uses inline assembly to access the storage slot defined by OWNER_STORAGE_POSITION.
 * @return s The OwnerStorage struct in storage.
 */
function getOwnerStorage() pure returns (OwnerStorage storage s) {
    bytes32 position = OWNER_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

bytes32 constant PENDING_OWNER_STORAGE_POSITION = keccak256("erc173.owner.pending");

/**
 * @custom:storage-location erc8042:erc173.owner.pending
 */
struct PendingOwnerStorage {
    address pendingOwner;
}

/**
 * @notice Returns a pointer to the PendingOwner storage struct.
 * @dev Uses inline assembly to access the storage slot defined by PENDING_OWNER_STORAGE_POSITION.
 * @return s The PendingOwnerStorage struct in storage.
 */
function getPendingOwnerStorage() pure returns (PendingOwnerStorage storage s) {
    bytes32 position = PENDING_OWNER_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Renounce ownership of the contract.
 * @dev Sets the owner to address(0) and clears any pending owner,
 *      disabling all functions restricted to the owner.
 */
function renounceOwnership() {
    OwnerStorage storage ownerStorage = getOwnerStorage();
    if (msg.sender != ownerStorage.owner) {
        revert OwnerUnauthorizedAccount();
    }
    PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
    address previousOwner = ownerStorage.owner;
    ownerStorage.owner = address(0);
    pendingStorage.pendingOwner = address(0);
    emit OwnershipTransferred(previousOwner, address(0));
}

