// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Facet_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165FacetBase.t.sol";
import {IERC165} from "src/interfaceDetection/ERC165/ERC165Facet.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract ExportSelectors_ERC165Facet_Unit_Test is ERC165Facet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = erc165Facet.exportSelectors();
        bytes memory expected = abi.encodePacked(IERC165.supportsInterface.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

