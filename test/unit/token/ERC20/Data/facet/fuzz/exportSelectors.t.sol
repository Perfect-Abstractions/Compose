// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20DataFacet_Base_Test} from "test/unit/token/ERC20/Data/ERC20DataFacetBase.t.sol";
import {ERC20DataFacet} from "src/token/ERC20/Data/ERC20DataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20DataFacet_Unit_Test is ERC20DataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC20DataFacet.totalSupply.selector, ERC20DataFacet.balanceOf.selector, ERC20DataFacet.allowance.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
