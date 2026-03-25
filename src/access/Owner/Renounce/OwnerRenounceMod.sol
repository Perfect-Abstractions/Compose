// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-173 Renounce Ownership Module
 * @notice Provides logic to renounce ownership.
 */

/**
 * @dev This emits when ownership of a contract changes.
 */
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

/**
 * @notice Thrown when a non-owner attempts an action restricted to owner.
 */
error OwnerUnauthorizedAccount();

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
 * @notice Renounce ownership of the contract.
 * @dev Sets the owner to address(0), disabling all functions restricted to the owner.
 */
function renounceOwnership() {
    OwnerStorage storage s = getStorage();
    if (msg.sender != s.owner) {
        revert OwnerUnauthorizedAccount();
    }
    address previousOwner = s.owner;
    s.owner = address(0);
    emit OwnershipTransferred(previousOwner, address(0));
}

