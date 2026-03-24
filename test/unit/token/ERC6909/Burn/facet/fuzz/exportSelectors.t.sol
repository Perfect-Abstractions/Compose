// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909BurnFacet_Base_Test} from "test/unit/token/ERC6909/Burn/ERC6909BurnFacetBase.t.sol";
import {ERC6909BurnFacet} from "src/token/ERC6909/Burn/ERC6909BurnFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract ExportSelectors_ERC6909BurnFacet_Unit_Test is ERC6909BurnFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC6909BurnFacet.burn.selector, ERC6909BurnFacet.burnFrom.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
