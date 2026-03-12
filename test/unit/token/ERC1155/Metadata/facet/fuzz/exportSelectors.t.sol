// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155MetadataFacet_Base_Test} from "test/unit/token/ERC1155/Metadata/ERC1155MetadataFacetBase.t.sol";
import {ERC1155MetadataFacet} from "src/token/ERC1155/Metadata/ERC1155MetadataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract ExportSelectors_ERC1155MetadataFacet_Unit_Test is ERC1155MetadataFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC1155MetadataFacet.uri.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
