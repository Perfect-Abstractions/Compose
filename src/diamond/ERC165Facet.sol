// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {IERC165} from "../interfaces/IERC165.sol";
import {LibERC165} from "../libraries/LibERC165.sol";

/// @title ERC165Facet — ERC-165 Standard Interface Detection Facet
/// @notice Facet implementation of ERC-165 for diamond proxy pattern
/// @dev Allows querying which interfaces are implemented by the diamond
contract ERC165Facet is IERC165 {
    /// @notice Query if a contract implements an interface
    /// @param _interfaceId The interface identifier, as specified in ERC-165
    /// @dev This function checks if the diamond supports the given interface ID
    /// @return `true` if the contract implements `_interfaceId` and
    /// `_interfaceId` is not 0xffffffff, `false` otherwise
    function supportsInterface(bytes4 _interfaceId) external view override returns (bool) {
        return LibERC165.supportsInterface(_interfaceId);
    }
}
