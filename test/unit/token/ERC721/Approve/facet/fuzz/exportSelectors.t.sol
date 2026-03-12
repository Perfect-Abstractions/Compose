// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721ApproveFacet_Base_Test} from "test/unit/token/ERC721/Approve/ERC721ApproveFacetBase.t.sol";
import {ERC721ApproveFacet} from "src/token/ERC721/Approve/ERC721ApproveFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract ExportSelectors_ERC721ApproveFacet_Unit_Test is ERC721ApproveFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected =
            abi.encodePacked(ERC721ApproveFacet.approve.selector, ERC721ApproveFacet.setApprovalForAll.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

