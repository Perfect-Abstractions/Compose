// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet} from "src/interfaceDetection/ERC165/ERC165Facet.sol";

/**
 * @title ERC165FacetHarness
 * @notice Test harness that exposes ERC165Facet storage helpers as external
 */
contract ERC165FacetHarness is ERC165Facet {
    function initialize() external {
        // No-op; storage is implicitly available
    }

    function registerInterface(bytes4 _interfaceId) external {
        ERC165Storage storage s = getStorage();
        s.supportedInterfaces[_interfaceId] = true;
    }

    function unregisterInterface(bytes4 _interfaceId) external {
        ERC165Storage storage s = getStorage();
        s.supportedInterfaces[_interfaceId] = false;
    }

    function getStorageValue(bytes4 _interfaceId) external view returns (bool) {
        return getStorage().supportedInterfaces[_interfaceId];
    }

    function exposedGetStorage() external pure returns (bytes32) {
        return STORAGE_POSITION;
    }
}

