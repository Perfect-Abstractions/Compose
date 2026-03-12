// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {OwnerTransferFacet} from "src/access/Owner/Transfer/OwnerTransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract ExportSelectors_OwnerTransferFacet_Unit_Test is Base_Test {
    OwnerTransferFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new OwnerTransferFacet();
        vm.label(address(facet), "OwnerTransferFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerTransferFacet.transferOwnership.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

