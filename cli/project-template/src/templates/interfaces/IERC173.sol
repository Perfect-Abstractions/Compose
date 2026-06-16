// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-173 Contract Ownership Standard Interface
 * @notice Interface for contract ownership with custom errors
 * @dev This interface includes all custom errors used by ERC-173 implementations
 */
interface IERC173 {
    /**
     * @notice Thrown when attempting to transfer ownership while not being the owner.
     */
    error OwnableUnauthorizedAccount();

    /**
     * @notice Thrown when attempting to transfer ownership of a renounced contract.
     */
    error OwnableAlreadyRenounced();

    /**
     * @dev This emits when ownership of a contract changes.
     */
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @notice Get the address of the owner
     * @return The address of the owner.
     */
    function owner() external view returns (address);

    /**
     * @notice Set the address of the new owner of the contract
     * @dev Set _newOwner to address(0) to renounce any ownership.
     * @param _newOwner The address of the new owner of the contract
     */
    function transferOwnership(address _newOwner) external;
}
