// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Data_ERC165Facet_Fuzz_Unit_Test is ERC165Facet_Base_Test {
    function testFuzz_ShouldReturnTrue_IERC165Interface(bytes4) external view {
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_ShouldReturnFalse_InvalidInterfaceWhenUnregistered() external view {
        assertFalse(erc165Facet.supportsInterface(INVALID_INTERFACE_ID));
    }

    function test_ShouldReturnFalse_ZeroInterfaceWhenUnregistered() external view {
        assertFalse(erc165Facet.supportsInterface(ZERO_INTERFACE_ID));
    }

    function test_ShouldReturnFalse_UnregisteredInterfaces() external view {
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));
    }
}

