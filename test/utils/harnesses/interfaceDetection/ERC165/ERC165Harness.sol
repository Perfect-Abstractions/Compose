// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import "src/interfaceDetection/ERC165/ERC165Mod.sol" as ERC165Mod;

/**
 * @title ERC165ModHarness
 * @notice Test harness that exposes ERC165Mod storage and helpers as external
 */
contract ERC165Harness {
    function initialize() external {
        // No-op; storage is implicitly available
    }

    function registerInterface(bytes4 _interfaceId) external {
        ERC165Mod.registerInterface(_interfaceId);
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        ERC165Mod.ERC165Storage storage s = ERC165Mod.getStorage();
        return s.supportedInterfaces[_interfaceId];
    }

    function getStorageValue(bytes4 _interfaceId) external view returns (bool) {
        return ERC165Mod.getStorage().supportedInterfaces[_interfaceId];
    }

    function getStoragePosition() external pure returns (bytes32) {
        return keccak256("erc165");
    }

    function forceSetInterface(bytes4 _interfaceId, bool _supported) external {
        ERC165Mod.ERC165Storage storage s = ERC165Mod.getStorage();
        s.supportedInterfaces[_interfaceId] = _supported;
    }

    function registerMultipleInterfaces(bytes4[] calldata _interfaceIds) external {
        for (uint256 i = 0; i < _interfaceIds.length; i++) {
            ERC165Mod.registerInterface(_interfaceIds[i]);
        }
    }
}

