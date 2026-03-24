// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909DataFacet_Base_Test} from "test/unit/token/ERC6909/Data/ERC6909DataFacetBase.t.sol";
import {ERC6909DataFacet} from "src/token/ERC6909/Data/ERC6909DataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract ExportSelectors_ERC6909DataFacet_Unit_Test is ERC6909DataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC6909DataFacet.balanceOf.selector,
            ERC6909DataFacet.allowance.selector,
            ERC6909DataFacet.isOperator.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
