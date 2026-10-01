// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "@perfect-abstractions/compose/diamond/DiamondMod.sol" as DiamondMod;
import "@perfect-abstractions/compose/interfaceDetection/ERC165/ERC165Mod.sol" as ERC165Mod;
import {IERC20} from "@perfect-abstractions/compose/interfaces/IERC20.sol";

contract Diamond {
    constructor(address[] memory facets) {
        DiamondMod.addFacets(facets);
        ERC165Mod.registerInterface(type(IERC20).interfaceId);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}
