// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@perfect-abstractions/compose/diamond/DiamondMod.sol" as DiamondMod;
import "@perfect-abstractions/compose/access/Owner/OwnerMod.sol" as OwnerMod;

contract Diamond {
    constructor(address[] memory facets, address diamondOwner) {
        DiamondMod.addFacets(facets);
        OwnerMod.setContractOwner(diamondOwner);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}
