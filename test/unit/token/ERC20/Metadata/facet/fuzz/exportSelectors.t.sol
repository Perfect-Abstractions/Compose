// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20MetadataFacet_Base_Test} from "test/unit/token/ERC20/Metadata/ERC20MetadataFacetBase.t.sol";
import {ERC20MetadataFacet} from "src/token/ERC20/Metadata/ERC20MetadataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20MetadataFacet_Unit_Test is ERC20MetadataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC20MetadataFacet.name.selector, ERC20MetadataFacet.symbol.selector, ERC20MetadataFacet.decimals.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
