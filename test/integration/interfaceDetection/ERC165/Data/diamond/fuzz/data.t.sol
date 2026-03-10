// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Diamond_Base_Integration_Test} from "test/integration/interfaceDetection/ERC165/ERC165DiamondBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Data_ERC165Diamond_Fuzz_Integration_Test is ERC165Diamond_Base_Integration_Test {
    function test_ShouldSupportIERC165_WhenDiamondIsDeployedWithERC165Facet() external view {
        assertTrue(diamondERC165.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_ShouldReturnFalse_ForUnregisteredInterfaceBeforeRegistration() external view {
        assertFalse(diamondERC165.supportsInterface(IERC1155_INTERFACE_ID));
    }
}

