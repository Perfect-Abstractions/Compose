// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToSharesFacet} from "src/token/ERC4626/ConvertToShares/ERC4626ConvertToSharesFacet.sol";
import {ERC4626ConvertToSharesFacet_Base_Test} from "../ERC4626ConvertToSharesFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626ConvertToSharesFacet_Unit_Test is ERC4626ConvertToSharesFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(ERC4626ConvertToSharesFacet.convertToShares.selector);
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
