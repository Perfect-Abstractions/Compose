// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Mod_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165ModBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Data_ERC165Mod_Fuzz_Unit_Test is ERC165Mod_Base_Test {
    function test_ShouldReturnFalse_ForUnregisteredInterfaces() external view {
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(harness.supportsInterface(IERC20_INTERFACE_ID));
        assertFalse(harness.supportsInterface(CUSTOM_INTERFACE_ID));
    }

    function test_ShouldReturnFalse_AfterUnregistration() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldSupportSpecialIds_WhenRegistered() external {
        harness.registerInterface(ZERO_INTERFACE_ID);
        harness.registerInterface(INVALID_INTERFACE_ID);
        harness.registerInterface(IERC165_INTERFACE_ID);

        assertTrue(harness.supportsInterface(ZERO_INTERFACE_ID));
        assertTrue(harness.supportsInterface(INVALID_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC165_INTERFACE_ID));
    }
}

