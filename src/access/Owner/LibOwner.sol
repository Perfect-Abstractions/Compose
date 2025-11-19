// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-173 Contract Ownership
/// @notice Provides internal functions and storage layout for owner management.
library LibOwner {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Thrown when a non-owner attempts an action restricted to owner.
    error OwnerUnauthorizedAccount();
    /// @notice Thrown when attempting to transfer ownership from a renounced state.
    error OwnerAlreadyRenounced();

    bytes32 constant STORAGE_POSITION = keccak256("compose.owner");

    /// @custom:storage-location erc8042:compose.owner
    struct OwnerStorage {
        address owner;
    }

    /// @notice Returns a pointer to the ERC-173 storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s The OwnerStorage struct in storage.
    function getStorage() internal pure returns (OwnerStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Get the address of the owner
    /// @return The address of the owner.
    function owner() internal view returns (address) {
        return getStorage().owner;
    }

    /// @notice Reverts if the caller is not the owner.
    function requireOwner() internal view {
        if (getStorage().owner != msg.sender) {
            revert OwnerUnauthorizedAccount();
        }
    }

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) internal {
        OwnerStorage storage s = getStorage();
        address previousOwner = s.owner;
        if (previousOwner == address(0)) {
            revert OwnerAlreadyRenounced();
        }
        s.owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /// @notice Renounce ownership of the contract
    /// @dev Sets the owner to address(0), disabling all functions restricted to the owner.
    function renounceOwnership() internal {
        OwnerStorage storage s = getStorage();
        address previousOwner = s.owner;
        s.owner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }
}
