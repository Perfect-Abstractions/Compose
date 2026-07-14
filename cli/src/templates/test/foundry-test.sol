// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../src/Diamond.sol";
{{IMPORTS}}

contract DiamondTest is Test {
    Diamond diamond;

    function setUp() public {
        address[] memory facets = new address[]({{FACET_COUNT}});

        /* Base facet generation. */
{{BASE_LINES}}

        /* Library facet generation. */
{{LIBRARY_LINES}}

        diamond = new Diamond(facets);
    }

    function test_inspect_facetAddresses() public view {
        DiamondInspectFacet inspect = DiamondInspectFacet(address(diamond));
        address[] memory addresses = inspect.facetAddresses();
        assertEq(addresses.length, {{FACET_COUNT}});
    }
}
