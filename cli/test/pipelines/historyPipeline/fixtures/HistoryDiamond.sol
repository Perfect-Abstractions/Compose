// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@perfect-abstractions/compose/diamond/DiamondMod.sol" as DiamondMod;

contract HistoryDiamond {
    constructor(address upgradeFacet) {
        bytes32 ownerSlot = keccak256("erc173.owner");
        assembly {
            sstore(ownerSlot, caller())
        }

        address[] memory initialFacets = new address[](1);
        initialFacets[0] = upgradeFacet;
        DiamondMod.addFacets(initialFacets);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }
}
