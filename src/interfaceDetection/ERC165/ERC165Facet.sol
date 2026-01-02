// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

/**
 * @title ERC-165 Standard Interface Detection Interface
 * @notice Interface for detecting what interfaces a contract implements
 * @dev ERC-165 allows contracts to publish their supported interfaces
 */
interface IERC165 {
    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceId The interface identifier, as specified in ERC-165
     * @dev Interface identification is specified in ERC-165. This function
     * uses less than 30,000 gas.
     * @return `true` if the contract implements `_interfaceId` and
     * `_interfaceId` is not 0xffffffff, `false` otherwise
     */
    function supportsInterface(bytes4 _interfaceId) external view returns (bool);
}

/**
 * @title ERC165Facet — ERC-165 Standard Interface Detection Facet
 * @notice Facet implementation of ERC-165 for diamond proxy pattern
 * @dev Allows querying which interfaces are implemented by the diamond
 * Each facet is a standalone source code file following SCOP principles.
 */
contract ERC165Facet {
    /**
     * @notice Storage slot identifier for ERC-165 interface detection
     * @dev Defined using keccak256 hash following ERC-8042 standard
     */
    bytes32 constant STORAGE_POSITION = keccak256("compose.erc165");

    /**
     * @notice ERC-165 storage layout using the ERC-8042 standard
     * @custom:storage-location erc8042:compose.erc165
     */
    struct ERC165Storage {
        /**
         * @notice Mapping of interface IDs to whether they are supported
         */
        mapping(bytes4 => bool) supportedInterfaces;
    }

    /**
     * @notice Returns a pointer to the ERC-165 storage struct
     * @dev Uses inline assembly to bind the storage struct to the fixed storage position
     * @return s The ERC-165 storage struct
     */
    function getStorage() internal pure returns (ERC165Storage storage s) {
        bytes32 position = STORAGE_POSITION;
        assembly {
            s.slot := position
        }
    }

    /**
     * @notice Query if a contract implements an interface
     * @param _interfaceId The interface identifier, as specified in ERC-165
     * @dev This function checks if the diamond supports the given interface ID
     * @return `true` if the contract implements `_interfaceId` and
     * `_interfaceId` is not 0xffffffff, `false` otherwise
     */
    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        ERC165Storage storage s = getStorage();

        /**
         * If the ERC165 interface itself is being queried, return true
         * since this facet implements ERC165
         */
        if (_interfaceId == type(IERC165).interfaceId) {
            return true;
        }

        return s.supportedInterfaces[_interfaceId];
    }
}
