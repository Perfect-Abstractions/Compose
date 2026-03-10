// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20TransferFacet_Base_Test} from "test/unit/token/ERC20/Transfer/facet/ERC20TransferFacetBase.t.sol";
import {ERC20TransferFacet} from "src/token/ERC20/Transfer/ERC20TransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20TransferFacet_Unit_Test is ERC20TransferFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected =
            abi.encodePacked(ERC20TransferFacet.transfer.selector, ERC20TransferFacet.transferFrom.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
