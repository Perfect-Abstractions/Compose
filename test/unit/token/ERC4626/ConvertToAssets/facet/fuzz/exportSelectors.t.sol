// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToAssetsFacet} from "src/token/ERC4626/ConvertToAssets/ERC4626ConvertToAssetsFacet.sol";
import {ERC4626ConvertToAssetsFacet_Base_Test} from "../ERC4626ConvertToAssetsFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626ConvertToAssetsFacet_Unit_Test is ERC4626ConvertToAssetsFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(ERC4626ConvertToAssetsFacet.convertToAssets.selector);
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
