// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Gas_ERC165Facet_Fuzz_Unit_Test is ERC165Facet_Base_Test {
    function test_ShouldUseLessThan30kGas_WhenCheckingIERC165Support() external view {
        uint256 gasBefore = gasleft();
        erc165Facet.supportsInterface(IERC165_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 30000, "supportsInterface should use less than 30,000 gas");
    }

    function test_ShouldUseLessThan30kGas_WhenCheckingRegisteredInterfaceSupport() external {
        erc165Facet.registerInterface(IERC721_INTERFACE_ID);

        uint256 gasBefore = gasleft();
        erc165Facet.supportsInterface(IERC721_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 30000, "supportsInterface should use less than 30,000 gas");
    }

    function test_ShouldUseLessThan30kGas_WhenCheckingUnregisteredInterfaceSupport() external view {
        uint256 gasBefore = gasleft();
        erc165Facet.supportsInterface(CUSTOM_INTERFACE_ID);
        uint256 gasUsed = gasBefore - gasleft();

        assertLt(gasUsed, 30000, "supportsInterface should use less than 30,000 gas");
    }
}

