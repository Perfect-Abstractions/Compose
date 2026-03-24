// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@perfect-abstractions/compose/diamond/DiamondMod.sol" as DiamondMod;
import "@perfect-abstractions/compose/access/Owner/Data/OwnerDataMod.sol" as OwnerDataMod;

contract Diamond {
    constructor(address[] memory facets, address diamondOwner) {
        DiamondMod.addFacets(facets);
        OwnerDataMod.setContractOwner(diamondOwner);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}
