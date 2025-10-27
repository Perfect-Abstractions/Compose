// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/// @title ERC-165 Standard Interface Detection Interface
/// @notice Interface for detecting what interfaces a contract implements
/// @dev ERC-165 allows contracts to publish their supported interfaces
interface IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param _interfaceId The interface identifier, as specified in ERC-165
    /// @dev Interface identification is specified in ERC-165. This function
    /// uses less than 30,000 gas.
    /// @return `true` if the contract implements `_interfaceId` and
    /// `_interfaceId` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 _interfaceId) external view returns (bool);
}
