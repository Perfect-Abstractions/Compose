// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import "src/diamond/DiamondMod.sol" as DiamondMod;
import "src/access/Owner/Data/OwnerDataMod.sol" as OwnerDataMod;

contract DiamondProxyHarness {
    constructor(address[] memory _facets, address _diamondOwner) {
        DiamondMod.addFacets(_facets);
        OwnerDataMod.setContractOwner(_diamondOwner);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}
