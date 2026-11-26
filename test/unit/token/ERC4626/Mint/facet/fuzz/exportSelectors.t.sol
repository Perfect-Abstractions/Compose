// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626MintFacet} from "src/token/ERC4626/Mint/ERC4626MintFacet.sol";
import {ERC4626MintFacet_Base_Test} from "../ERC4626MintFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626MintFacet_Unit_Test is ERC4626MintFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(
            ERC4626MintFacet.maxMint.selector, ERC4626MintFacet.previewMint.selector, ERC4626MintFacet.mint.selector
        );
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
