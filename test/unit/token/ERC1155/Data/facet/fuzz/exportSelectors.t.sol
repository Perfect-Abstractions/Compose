// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155DataFacet_Base_Test} from "test/unit/token/ERC1155/Data/ERC1155DataFacetBase.t.sol";
import {ERC1155DataFacet} from "src/token/ERC1155/Data/ERC1155DataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract ExportSelectors_ERC1155DataFacet_Unit_Test is ERC1155DataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC1155DataFacet.balanceOf.selector,
            ERC1155DataFacet.balanceOfBatch.selector,
            ERC1155DataFacet.isApprovedForAll.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
