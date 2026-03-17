// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DiamondMod} from "@perfect-abstractions/compose/modules/DiamondMod.sol";
import {OwnerMod} from "@perfect-abstractions/compose/modules/OwnerMod.sol";

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
