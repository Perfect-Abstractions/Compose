// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20ApproveFacet} from "src/token/ERC20/Approve/ERC20ApproveFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract ExportSelectors_ERC20ApproveFacet_Unit_Test is Base_Test {
    ERC20ApproveFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20ApproveFacet();
        vm.label(address(facet), "ERC20ApproveFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(ERC20ApproveFacet.approve.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
