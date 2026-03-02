// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title OwnerTwoStepRenounceFacet
 */
contract OwnerTwoStepRenounceFacet {
    /**
     * @dev This emits when ownership of a contract changes.
     */
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    /**
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
    function getPendingOwnerStorage() internal pure returns (PendingOwnerStorage storage s) {
        bytes32 position = PENDING_OWNER_STORAGE_POSITION;
        assembly {
            s.slot := position
        }
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
