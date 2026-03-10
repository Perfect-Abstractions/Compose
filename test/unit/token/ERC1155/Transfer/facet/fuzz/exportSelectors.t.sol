// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155TransferFacet_Base_Test} from "test/unit/token/ERC1155/Transfer/ERC1155TransferFacetBase.t.sol";
import {ERC1155TransferFacet} from "src/token/ERC1155/Transfer/ERC1155TransferFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract ExportSelectors_ERC1155TransferFacet_Unit_Test is ERC1155TransferFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC1155TransferFacet.safeTransferFrom.selector, ERC1155TransferFacet.safeBatchTransferFrom.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
