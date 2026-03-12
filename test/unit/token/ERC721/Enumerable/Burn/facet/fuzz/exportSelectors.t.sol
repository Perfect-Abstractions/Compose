// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721EnumerableBurnFacet_Base_Test
} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableBurnFacetBase.t.sol";
import {ERC721EnumerableBurnFacet} from "src/token/ERC721/Enumerable/Burn/ERC721EnumerableBurnFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract ExportSelectors_ERC721EnumerableBurnFacet_Unit_Test is ERC721EnumerableBurnFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC721EnumerableBurnFacet.burn.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

