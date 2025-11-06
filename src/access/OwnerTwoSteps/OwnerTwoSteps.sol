// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-173 Two-Step Contract Ownership
contract OwnerTwoStepsFacet {
    /// @dev This emits when ownership of a contract started transferring to the new owner for accepting the ownership.
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    /// @notice Thrown when a non-owner attempts an action restricted to owner.
    error OwnerUnauthorizedAccount();

    bytes32 constant STORAGE_POSITION = keccak256("compose.owner");

    /// @custom:storage-location erc8042:compose.owner
    struct OwnerTwoStepsStorage {
        address owner;
        address pendingOwner;
    }

    /// @notice Returns a pointer to the ERC-173 storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s The EOwnerTwoStepsStorage struct in storage.
    function getStorage() internal pure returns (OwnerTwoStepsStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Get the address of the owner
    /// @return The address of the owner.
    function owner() external view returns (address) {
        return getStorage().owner;
    }

    /// @notice Get the address of the pending owner
    /// @return The address of the pending owner.
    function pendingOwner() external view returns (address) {
        return getStorage().pendingOwner;
    }

    /// @notice Set the address of the new owner of the contract
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external {
        OwnerTwoStepsStorage storage s = getStorage();
        if (msg.sender != s.owner) {
            revert OwnerUnauthorizedAccount();
        }
        s.pendingOwner = _newOwner;
        emit OwnershipTransferStarted(s.owner, _newOwner);
    }

    /// @notice Accept the ownership of the contract
    /// @dev Only the pending owner can call this function.
    function acceptOwnership() external {
        OwnerTwoStepsStorage storage s = getStorage();
        if (msg.sender != s.pendingOwner) {
            revert OwnerUnauthorizedAccount();
        }
        address oldOwner = s.owner;
        s.owner = s.pendingOwner;
        s.pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, s.owner);
    }

    /// @notice Renounce ownership of the contract
    /// @dev Sets the owner to address(0), disabling all functions restricted to the owner.
    function renounceOwnership() external {
        OwnerTwoStepsStorage storage s = getStorage();
        if (msg.sender != s.owner) {
            revert OwnerUnauthorizedAccount();
        }
        address previousOwner = s.owner;
        s.owner = address(0);
        s.pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }
}
