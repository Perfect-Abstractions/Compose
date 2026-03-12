// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155ApproveFacet_Base_Test} from "test/unit/token/ERC1155/Approve/ERC1155ApproveFacetBase.t.sol";
import {ERC1155ApproveFacet} from "src/token/ERC1155/Approve/ERC1155ApproveFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract ExportSelectors_ERC1155ApproveFacet_Unit_Test is ERC1155ApproveFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC1155ApproveFacet.setApprovalForAll.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
