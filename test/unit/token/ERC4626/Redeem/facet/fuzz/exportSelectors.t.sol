// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626RedeemFacet} from "src/token/ERC4626/Redeem/ERC4626RedeemFacet.sol";
import {ERC4626RedeemFacet_Base_Test} from "../ERC4626RedeemFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626RedeemFacet_Unit_Test is ERC4626RedeemFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(
            ERC4626RedeemFacet.maxRedeem.selector,
            ERC4626RedeemFacet.previewRedeem.selector,
            ERC4626RedeemFacet.redeem.selector
        );
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
