// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909OperatorFacet_Base_Test} from "test/unit/token/ERC6909/Operator/ERC6909OperatorFacetBase.t.sol";
import {ERC6909OperatorFacet} from "src/token/ERC6909/Operator/ERC6909OperatorFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract ExportSelectors_ERC6909OperatorFacet_Unit_Test is ERC6909OperatorFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC6909OperatorFacet.setOperator.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
