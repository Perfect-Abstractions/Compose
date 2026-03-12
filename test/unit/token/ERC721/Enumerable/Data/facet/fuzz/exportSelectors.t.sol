// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721EnumerableDataFacet_Base_Test
} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableDataFacetBase.t.sol";
import {ERC721EnumerableDataFacet} from "src/token/ERC721/Enumerable/Data/ERC721EnumerableDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract ExportSelectors_ERC721EnumerableDataFacet_Unit_Test is ERC721EnumerableDataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC721EnumerableDataFacet.totalSupply.selector,
            ERC721EnumerableDataFacet.tokenOfOwnerByIndex.selector,
            ERC721EnumerableDataFacet.tokenByIndex.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

