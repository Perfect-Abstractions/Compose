// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {OwnerRenounceFacet} from "src/access/Owner/Renounce/OwnerRenounceFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract ExportSelectors_OwnerRenounceFacet_Unit_Test is Base_Test {
    OwnerRenounceFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new OwnerRenounceFacet();
        vm.label(address(facet), "OwnerRenounceFacet");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerRenounceFacet.renounceOwnership.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}

