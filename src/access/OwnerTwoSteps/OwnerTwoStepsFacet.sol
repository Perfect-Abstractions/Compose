// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-173 Two-Step Contract Ownership
 */
contract OwnerTwoStepsFacet {
    /**
     * @dev This emits when ownership of a contract started transferring to the new owner for accepting the ownership.
     */
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);

    /**
     * @dev This emits when ownership of a contract changes.
     */
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    /**
     * @notice Thrown when a non-owner attempts an action restricted to owner.
     */
    error OwnerUnauthorizedAccount();

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
    function getOwnerStorage() internal pure returns (OwnerStorage storage s) {
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
    function getPendingOwnerStorage() internal pure returns (PendingOwnerStorage storage s) {
        bytes32 position = PENDING_OWNER_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Get the address of the owner
     * @return The address of the owner.
     */
    function owner() external view returns (address) {
        return getOwnerStorage().owner;
    }

    /**
     * @notice Get the address of the pending owner
     * @return The address of the pending owner.
     */
    function pendingOwner() external view returns (address) {
        return getPendingOwnerStorage().pendingOwner;
    }

    /**
     * @notice Set the address of the new owner of the contract
     * @param _newOwner The address of the new owner of the contract
     */
    function transferOwnership(address _newOwner) external {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        if (msg.sender != ownerStorage.owner) {
            revert OwnerUnauthorizedAccount();
        }
        getPendingOwnerStorage().pendingOwner = _newOwner;
        emit OwnershipTransferStarted(ownerStorage.owner, _newOwner);
    }

    /**
     * @notice Accept the ownership of the contract
     * @dev Only the pending owner can call this function.
     */
    function acceptOwnership() external {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
        if (msg.sender != pendingStorage.pendingOwner) {
            revert OwnerUnauthorizedAccount();
        }
        address oldOwner = ownerStorage.owner;
        ownerStorage.owner = pendingStorage.pendingOwner;
        pendingStorage.pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, ownerStorage.owner);
    }

    /**
     * @notice Renounce ownership of the contract
     * @dev Sets the owner to address(0), disabling all functions restricted to the owner.
     */
    function renounceOwnership() external {
        OwnerStorage storage ownerStorage = getOwnerStorage();
        PendingOwnerStorage storage pendingStorage = getPendingOwnerStorage();
        if (msg.sender != ownerStorage.owner) {
            revert OwnerUnauthorizedAccount();
        }
        address previousOwner = ownerStorage.owner;
        ownerStorage.owner = address(0);
        pendingStorage.pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }
}
