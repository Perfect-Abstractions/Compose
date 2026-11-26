// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DataFacet} from "src/token/ERC4626/Data/ERC4626DataFacet.sol";
import {ERC4626DataFacet_Base_Test} from "../ERC4626DataFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626DataFacet_Unit_Test is ERC4626DataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(ERC4626DataFacet.asset.selector, ERC4626DataFacet.totalAssets.selector);
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
