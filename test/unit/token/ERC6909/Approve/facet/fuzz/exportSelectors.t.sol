// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909ApproveFacet_Base_Test} from "test/unit/token/ERC6909/Approve/ERC6909ApproveFacetBase.t.sol";
import {ERC6909ApproveFacet} from "src/token/ERC6909/Approve/ERC6909ApproveFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract ExportSelectors_ERC6909ApproveFacet_Unit_Test is ERC6909ApproveFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC6909ApproveFacet.approve.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
