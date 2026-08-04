// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import "src/diamond/DiamondMod.sol" as DiamondMod;

contract DiamondModHarness {
    constructor(address[] memory _facets) {
        DiamondMod.addFacets(_facets);
    }

    function addFacets(address[] memory _facets) external {
        DiamondMod.addFacets(_facets);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}
