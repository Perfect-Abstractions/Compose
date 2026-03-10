// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721EnumerableTransferFacet_Base_Test
} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableTransferFacetBase.t.sol";
import {ERC721EnumerableTransferFacet} from "src/token/ERC721/Enumerable/Transfer/ERC721EnumerableTransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract ExportSelectors_ERC721EnumerableTransferFacet_Unit_Test is ERC721EnumerableTransferFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC721EnumerableTransferFacet.transferFrom.selector,
            bytes4(keccak256("safeTransferFrom(address,address,uint256)")),
            bytes4(keccak256("safeTransferFrom(address,address,uint256,bytes)"))
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}

