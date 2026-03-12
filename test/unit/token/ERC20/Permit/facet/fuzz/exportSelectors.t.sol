// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20PermitFacet_Base_Test} from "test/unit/token/ERC20/Permit/ERC20PermitFacetBase.t.sol";
import {ERC20PermitFacet} from "src/token/ERC20/Permit/ERC20PermitFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20PermitFacet_Unit_Test is ERC20PermitFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC20PermitFacet.nonces.selector,
            ERC20PermitFacet.DOMAIN_SEPARATOR.selector,
            ERC20PermitFacet.permit.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
