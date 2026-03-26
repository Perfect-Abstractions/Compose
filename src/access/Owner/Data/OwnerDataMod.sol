// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/*
 * @title ERC-173 Contract Ownership
 * @notice Provides internal functions and storage layout for owner management.
 */

/**
 * @dev This emits when ownership of a contract changes.
 */
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

/*
 * @notice Thrown when a non-owner attempts an action restricted to owner.
 */
error OwnerUnauthorizedAccount();
/*
 * @notice Thrown when attempting to transfer ownership from a renounced state.
 */
error OwnerAlreadyRenounced();

bytes32 constant STORAGE_POSITION = keccak256("erc173.owner");

/**
 * @custom:storage-location erc8042:erc173.owner
 */
struct OwnerStorage {
    address owner;
}

/**
 * @notice Returns a pointer to the ERC-173 storage struct.
 * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
 * @return s The OwnerStorage struct in storage.
 */
function getStorage() pure returns (OwnerStorage storage s) {
    bytes32 position = STORAGE_POSITION;
    assembly {
        s.slot := position
    }
}

/**
 * @notice Sets the stored owner and emits `OwnershipTransferred` with `previousOwner == address(0)`.
 * @dev Does not enforce access control. Use from trusted init paths (for example the diamond constructor);
 *      for guarded changes, use a transfer facet with `OwnerTransferMod` or similar.
 * @param _initialOwner Address written to `OwnerStorage.owner`.
 */
function setContractOwner(address _initialOwner) {
    OwnerStorage storage s = getStorage();
    s.owner = _initialOwner;
    emit OwnershipTransferred(address(0), _initialOwner);
}

/**
 * @notice Get the address of the owner
 * @return The address of the owner.
 */
function owner() view returns (address) {
    return getStorage().owner;
}

/**
 * @notice Reverts if the caller is not the owner.
 */
function requireOwner() view {
    if (getStorage().owner != msg.sender) {
        revert OwnerUnauthorizedAccount();
    }
}
