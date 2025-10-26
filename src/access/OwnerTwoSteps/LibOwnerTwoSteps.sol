// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-173 Two-Step Contract Ownership Library
/// @notice Provides two-step ownership transfer logic for facets or modular contracts.
library LibOwnerTwoSteps {
    /// @dev Emitted when ownership transfer is initiated (pending owner set).
    event OwnershipTransferStarted(address indexed _previousOwner, address indexed _newOwner);
    /// @dev Emitted when ownership transfer is finalized.
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
    /// @return s The ERC173Storage struct in storage.
    function getStorage() internal pure returns (OwnerTwoStepsStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Returns the current owner.
    function owner() internal view returns (address) {
        return getStorage().owner;
    }

    /// @notice Returns the pending owner (if any).
    function pendingOwner() internal view returns (address) {
        return getStorage().pendingOwner;
    }

    /// @notice Reverts if the caller is not the owner.
    function requireOwner() internal view {
        if (getStorage().owner != msg.sender) {
            revert OwnerUnauthorizedAccount();
        }
    }

    /// @notice Initiates a two-step ownership transfer.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) internal {
        OwnerTwoStepsStorage storage s = getStorage();
        s.pendingOwner = _newOwner;
        emit OwnershipTransferStarted(s.owner, _newOwner);
    }

    /// @notice Finalizes ownership transfer; must be called by the pending owner.
    function acceptOwnership() internal {
        OwnerTwoStepsStorage storage s = getStorage();
        address oldOwner = s.owner;
        s.owner = s.pendingOwner;
        s.pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, s.owner);
    }

    /// @notice Renounce ownership of the contract
    /// @dev Sets the owner to address(0), disabling all functions restricted to the owner.
    function renounceOwnership() internal {
        OwnerTwoStepsStorage storage s = getStorage();
        address previousOwner = s.owner;
        s.owner = address(0);
        s.pendingOwner = address(0);
        emit OwnershipTransferred(previousOwner, address(0));
    }
}
