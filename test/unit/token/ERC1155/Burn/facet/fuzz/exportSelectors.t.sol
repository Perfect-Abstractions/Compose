// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155BurnFacet_Base_Test} from "test/unit/token/ERC1155/Burn/ERC1155BurnFacetBase.t.sol";
import {ERC1155BurnFacet} from "src/token/ERC1155/Burn/ERC1155BurnFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract ExportSelectors_ERC1155BurnFacet_Unit_Test is ERC1155BurnFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC1155BurnFacet.burn.selector,
            ERC1155BurnFacet.burnBatch.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
