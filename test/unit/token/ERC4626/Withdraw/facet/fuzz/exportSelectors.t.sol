// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626WithdrawFacet} from "src/token/ERC4626/Withdraw/ERC4626WithdrawFacet.sol";
import {ERC4626WithdrawFacet_Base_Test} from "../ERC4626WithdrawFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626WithdrawFacet_Unit_Test is ERC4626WithdrawFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(
            ERC4626WithdrawFacet.maxWithdraw.selector,
            ERC4626WithdrawFacet.previewWithdraw.selector,
            ERC4626WithdrawFacet.withdraw.selector
        );
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
