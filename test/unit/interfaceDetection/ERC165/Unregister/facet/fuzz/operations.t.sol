// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Operations_ERC165Facet_Fuzz_Unit_Test is ERC165Facet_Base_Test {
    function test_ShouldHandleRegisterUnregisterCycles() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));

        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldHandleMixedInterfaceOperations() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC20_INTERFACE_ID);
        erc165Facet.registerInterface(CUSTOM_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));

        erc165Facet.unregisterInterface(IERC20_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));

        erc165Facet.registerInterface(ZERO_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertFalse(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(ZERO_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }
}

