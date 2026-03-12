// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract UnregisterInterface_ERC165Facet_Fuzz_Unit_Test is ERC165Facet_Base_Test {
    function test_ShouldUnsetSupport_WhenUnregisteringRegisteredInterface() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);

        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldNotAffectOtherInterfaces_WhenUnregisteringOne() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC20_INTERFACE_ID);

        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);

        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
    }

    function test_ShouldRemainSupported_WhenAttemptingToUnregisterIERC165() external {
        erc165Facet.unregisterInterface(IERC165_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_ShouldBeIdempotent_WhenUnregisteringSameInterfaceTwice() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);
        erc165Facet.unregisterInterface(IERC721_INTERFACE_ID);

        assertFalse(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function testFuzz_ShouldUnsetSupport_WhenUnregisteringInterface(bytes4 interfaceId) external {
        vm.assume(interfaceId != IERC165_INTERFACE_ID);

        erc165Facet.registerInterface(interfaceId);
        erc165Facet.unregisterInterface(interfaceId);

        assertFalse(erc165Facet.supportsInterface(interfaceId));
    }
}

