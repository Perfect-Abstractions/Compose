// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DepositFacet} from "src/token/ERC4626/Deposit/ERC4626DepositFacet.sol";
import {ERC4626DepositFacet_Base_Test} from "../ERC4626DepositFacetBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract ExportSelectors_ERC4626DepositFacet_Unit_Test is ERC4626DepositFacet_Base_Test {
    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory expected = abi.encodePacked(
            ERC4626DepositFacet.maxDeposit.selector,
            ERC4626DepositFacet.previewDeposit.selector,
            ERC4626DepositFacet.deposit.selector
        );
        assertEq(facet.exportSelectors(), expected, "exportSelectors");
    }
}
