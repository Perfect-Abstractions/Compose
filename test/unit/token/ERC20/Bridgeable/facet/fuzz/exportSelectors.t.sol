// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20BridgeableFacet_Base_Test} from "test/unit/token/ERC20/Bridgeable/ERC20BridgeableFacetBase.t.sol";
import {ERC20BridgeableFacet} from "src/token/ERC20/Bridgeable/ERC20BridgeableFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20BridgeableFacet_Unit_Test is ERC20BridgeableFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC20BridgeableFacet.crosschainMint.selector,
            ERC20BridgeableFacet.crosschainBurn.selector,
            ERC20BridgeableFacet.checkTokenBridge.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
