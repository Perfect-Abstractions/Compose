// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-173 Contract Ownership
contract ERC173Facet {
    /// @dev This emits when ownership of a contract changes.
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Thrown when attempting to transfer ownership while not being the owner.
    error OwnableUnauthorizedAccount();
    event OwnershipTransferRequested(address indexed previousOwner, address indexed newOwner);
    error OwnableNoPendingOwner();

    bytes32 constant STORAGE_POSITION = keccak256("compose.erc173");

    /// @custom:storage-location erc8042:compose.erc173
    struct ERC173Storage {
        address owner;
        address pendingOwner;
    }

    /// @notice Returns a pointer to the ERC-173 storage struct.
    /// @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
    /// @return s The ERC173Storage struct in storage.
    function getStorage() internal pure returns (ERC173Storage storage s) {
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

    /// @notice Set the address of the new owner of the contract
    /// @dev Set _newOwner to address(0) to renounce any ownership.
    /// @param _newOwner The address of the new owner of the contract
    function transferOwnership(address _newOwner) external { // q this works best for remouncing ownership 
        ERC173Storage storage s = getStorage();
        if (msg.sender != s.owner) revert OwnableUnauthorizedAccount();
        emit OwnershipTransferred(s.owner, _newOwner); // q dual transfer of ownership is best practice 
        s.owner = _newOwner;
    }

        /// @notice Initiate a two-step ownership transfer by setting a pending owner.
    /// @dev The pending owner must call acceptOwnership() to complete the transfer.
    /// @param _newOwner The address proposed as the new owner.
    function initiateOwnershipTransfer(address _newOwner) external {
        ERC173Storage storage s = getStorage();
        if (msg.sender != s.owner) revert OwnableUnauthorizedAccount();
        s.pendingOwner = _newOwner;
        emit OwnershipTransferRequested(s.owner, _newOwner);
    }

    /// @notice Accept a previously initiated ownership transfer.
    /// @dev Can only be called by the pending owner to complete the two-step transfer.
    function acceptOwnership() external {
        ERC173Storage storage s = getStorage();
        address pending = s.pendingOwner;
        if (pending == address(0) || msg.sender != pending) revert OwnableNoPendingOwner();
        address previous = s.owner;
        s.owner = pending;
        s.pendingOwner = address(0);
        emit OwnershipTransferred(previous, msg.sender);
    }

}
