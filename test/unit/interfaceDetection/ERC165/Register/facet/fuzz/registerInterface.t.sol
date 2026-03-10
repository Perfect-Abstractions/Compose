// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract RegisterInterface_ERC165Facet_Fuzz_Unit_Test is ERC165Facet_Base_Test {
    function test_ShouldMarkSupported_WhenRegisteringSingleInterface() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldMarkSupported_WhenRegisteringMultipleInterfaces() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC20_INTERFACE_ID);
        erc165Facet.registerInterface(CUSTOM_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(IERC20_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID));
    }

    function test_ShouldRemainSupported_WhenRegisteringIERC165OrOtherInterfaces() external {
        erc165Facet.registerInterface(IERC165_INTERFACE_ID);
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC165_INTERFACE_ID));
    }

    function test_ShouldAllowRegisteringSpecialIds() external {
        erc165Facet.registerInterface(ZERO_INTERFACE_ID);
        erc165Facet.registerInterface(INVALID_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(ZERO_INTERFACE_ID));
        assertTrue(erc165Facet.supportsInterface(INVALID_INTERFACE_ID));
    }

    function test_ShouldBeIdempotent_WhenRegisteringSameInterfaceTwice() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        assertTrue(erc165Facet.supportsInterface(IERC721_INTERFACE_ID));
    }

    function testFuzz_ShouldMarkSupported_WhenRegisteringInterface(bytes4 interfaceId) external {
        erc165Facet.registerInterface(interfaceId);
        assertTrue(erc165Facet.supportsInterface(interfaceId));
    }

    function testFuzz_ShouldTrackAllInterfaces_WhenRegisteringMany(bytes4[] calldata interfaceIds) external {
        vm.assume(interfaceIds.length > 0 && interfaceIds.length <= 20);

        for (uint256 i = 0; i < interfaceIds.length; i++) {
            erc165Facet.registerInterface(interfaceIds[i]);
            assertTrue(erc165Facet.supportsInterface(interfaceIds[i]));
        }
    }
}

