// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-173 Two-Step Ownership Transfer Module
 * @notice Provides logic for two-step ownership transfers.
 */

/**
 * @dev Emitted when ownership transfer is initiated (pending owner set).
 */
event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);

/**
 * @dev Emitted when ownership transfer is finalized.
 */
event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

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

bytes32 constant PENDING_OWNER_STORAGE_POSITION = keccak256("erc173.owner.pending");

/**
 * @custom:storage-location erc8042:erc173.owner.pending
 */
struct PendingOwnerStorage {
    address pendingOwner;
}

/**
 * @notice Returns a pointer to the Owner storage struct.
 * @dev Uses inline assembly to access the storage slot defined by OWNER_STORAGE_POSITION.
 * @return s The OwnerStorage struct in storage.
 */
function getOwnerStorage() pure returns (OwnerStorage storage s) {
    bytes32 position = OWNER_STORAGE_POSITION;
    assembly {
        s.slot := position
    }
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
 * @notice Initiates a two-step ownership transfer.
 * @param _newOwner The address of the new owner of the contract.
 */
function transferOwnership(address _newOwner) {
    OwnerStorage storage ownerStorage = getOwnerStorage();
    if (msg.sender != ownerStorage.owner) {
        revert OwnerUnauthorizedAccount();
    }
    getPendingOwnerStorage().pendingOwner = _newOwner;
    emit OwnershipTransferStarted(ownerStorage.owner, _newOwner);
}

/**
 * @notice Finalizes ownership transfer.
 * @dev Only the pending owner can call this function.
 */
function acceptOwnership() {
    OwnerStorage storage ownerStorage = getOwnerStorage();
    PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
    if (msg.sender != pendingStorage.pendingOwner) {
        revert OwnerUnauthorizedAccount();
    }
    address previousOwner = ownerStorage.owner;
    ownerStorage.owner = pendingStorage.pendingOwner;
    pendingStorage.pendingOwner = address(0);
    emit OwnershipTransferred(previousOwner, ownerStorage.owner);
}

