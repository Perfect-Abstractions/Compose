// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-173 Two-Step Contract Ownership Library
 * @notice Provides two-step ownership transfer logic for facets or modular contracts.
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
/*
 * @notice Thrown when attempting to transfer ownership from a renounced state.
 */
error OwnerAlreadyRenounced();

bytes32 constant OWNER_STORAGE_POSITION = keccak256("compose.owner");

/**
 * @custom:storage-location erc8042:compose.owner
 */
struct OwnerStorage {
    address owner;
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

bytes32 constant PENDING_OWNER_STORAGE_POSITION = keccak256("compose.owner.pending");

/**
 * @custom:storage-location erc8042:compose.owner.pending
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
 * @notice Returns the current owner.
 */
function owner() view returns (address) {
    return getOwnerStorage().owner;
}

/**
 * @notice Returns the pending owner (if any).
 */
function pendingOwner() view returns (address) {
    return getPendingOwnerStorage().pendingOwner;
}

/**
 * @notice Reverts if the caller is not the owner.
 */
function requireOwner() view {
    if (getOwnerStorage().owner != msg.sender) {
        revert OwnerUnauthorizedAccount();
    }
}

/**
 * @notice Initiates a two-step ownership transfer.
 * @param _newOwner The address of the new owner of the contract
 */
function transferOwnership(address _newOwner) {
    OwnerStorage storage ownerStorage = getOwnerStorage();
    address previousOwner = ownerStorage.owner;
    if (previousOwner == address(0)) {
        revert OwnerAlreadyRenounced();
    }
    getPendingOwnerStorage().pendingOwner = _newOwner;
    emit OwnershipTransferStarted(previousOwner, _newOwner);
}

/**
 * @notice Finalizes ownership transfer; must be called by the pending owner.
 */
function acceptOwnership() {
    OwnerStorage storage ownerStorage = getOwnerStorage();
    PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
    address oldOwner = ownerStorage.owner;
    ownerStorage.owner = pendingStorage.pendingOwner;
    pendingStorage.pendingOwner = address(0);
    emit OwnershipTransferred(oldOwner, ownerStorage.owner);
}

/**
 * @notice Renounce ownership of the contract
 * @dev Sets the owner to address(0), disabling all functions restricted to the owner.
 */
function renounceOwnership() {
    OwnerStorage storage ownerStorage = getOwnerStorage();
    PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
    address previousOwner = ownerStorage.owner;
    ownerStorage.owner = address(0);
    pendingStorage.pendingOwner = address(0);
    emit OwnershipTransferred(previousOwner, address(0));
}
