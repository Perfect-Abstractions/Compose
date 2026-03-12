// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20BurnFacet_Base_Test} from "test/unit/token/ERC20/Burn/facet/ERC20BurnFacetBase.t.sol";
import {ERC20BurnFacet} from "src/token/ERC20/Burn/ERC20BurnFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20BurnFacet_Unit_Test is ERC20BurnFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC20BurnFacet.burn.selector, ERC20BurnFacet.burnFrom.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
