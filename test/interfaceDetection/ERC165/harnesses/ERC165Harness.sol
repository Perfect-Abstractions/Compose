// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "../../../../src/interfaceDetection/ERC165/ERC165Mod.sol" as ERC165Mod;

/**
 * @title LibERC165 Test Harness
 */
/**
 * @notice Exposes internal LibERC165 functions as external for testing
 */
contract ERC165Harness {
    /**
     * @notice Initialize the ERC165 storage (for testing)
     */
    function initialize() external {
        /**
         * No initialization needed for basic ERC165
         */
        /**
         * Storage is automatically available
         */
    }

    /**
     * @notice Register an interface
     */
    function registerInterface(bytes4 _interfaceId) external {
        ERC165Mod.registerInterface(_interfaceId);
    }

    /**
     * @notice Check if an interface is supported
     */
    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        ERC165Mod.ERC165Storage storage s = ERC165Mod.getStorage();
        return s.supportedInterfaces[_interfaceId];
    }

    /**
     * @notice Get storage directly (for testing storage consistency)
     */
    function getStorageValue(bytes4 _interfaceId) external view returns (bool) {
        return ERC165Mod.getStorage().supportedInterfaces[_interfaceId];
    }

    /**
     * @notice Get the storage position
     */
    function getStoragePosition() external pure returns (bytes32) {
        return keccak256("compose.erc165");
    }

    /**
     * @notice Force set an interface support value (for testing edge cases)
     */
    function forceSetInterface(bytes4 _interfaceId, bool _supported) external {
        ERC165Mod.ERC165Storage storage s = ERC165Mod.getStorage();
        s.supportedInterfaces[_interfaceId] = _supported;
    }

    /**
     * @notice Register multiple interfaces at once (for testing)
     */
    function registerMultipleInterfaces(bytes4[] calldata _interfaceIds) external {
        for (uint256 i = 0; i < _interfaceIds.length; i++) {
            ERC165Mod.registerInterface(_interfaceIds[i]);
        }
    }
}
