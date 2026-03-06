// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-173 Contract Facet for Ownership Transfer
 */
contract OwnerTransferFacet {
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
     * @notice Returns a pointer to the owner storage struct.
     * @dev Uses inline assembly to access the storage slot defined by STORAGE_POSITION.
     * @return s The OwnerStorage struct in storage.
     */
    function getStorage() internal pure returns (OwnerStorage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Set the address of the new owner of the contract.
     * @dev Set _newOwner to address(0) to renounce any ownership.
     * @param _newOwner The address of the new owner of the contract.
     */
    function transferOwnership(address _newOwner) external {
        OwnerStorage storage s = getStorage();
        if (msg.sender != s.owner) {
            revert OwnerUnauthorizedAccount();
        }
        address previousOwner = s.owner;
        s.owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @notice Exports the function selectors of the OwnerTransferFacet
     * @dev This function is use as a selector discovery mechanism for diamonds
     * @return selectors The exported function selectors of the OwnerTransferFacet
     */
    function exportSelectors() external pure returns (bytes memory) {
        return bytes.concat(this.transferOwnership.selector);
    }
}
