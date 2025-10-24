// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-173 Contract Ownership
library LibERC173 {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Thrown when attempting to transfer ownership of a renounced contract.
    error OwnableAlreadyRenounced();

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc173");

    /// @custom:storage-location erc8042:compose.erc173
    struct ERC173Storage {
        address owner;
    }

    /// @notice Returns a pointer to the ERC-173 storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s The ERC173Storage struct in storage.
    function _getStorage() internal pure returns (ERC173Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /// @notice Get the address of the owner
    /// @return The address of the owner.
    function _owner() internal view returns (address) {
        return _getStorage().owner;
    }

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function _transferOwnership(address _newOwner) internal {
        ERC173Storage storage s = _getStorage();
        if (s.owner == address(0)) revert OwnableAlreadyRenounced();
        address previousOwner = s.owner;
        s.owner = _newOwner;

        emit OwnershipTransferred(previousOwner, _newOwner);
    }
}
