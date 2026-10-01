// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Script} from "forge-std/Script.sol";
import {Diamond} from "../src/Diamond.sol";
import {CanonicalStorageFacet} from "../src/CanonicalStorageFacet.sol";
import {DiamondInspectFacet} from "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol";
import {ERC20DataFacet} from "@perfect-abstractions/compose/token/ERC20/Data/ERC20DataFacet.sol";
import {ERC20ApproveFacet} from "@perfect-abstractions/compose/token/ERC20/Approve/ERC20ApproveFacet.sol";
import {ERC20TransferFacet} from "@perfect-abstractions/compose/token/ERC20/Transfer/ERC20TransferFacet.sol";

contract DeployScript is Script {
    function run() public returns (Diamond diamond) {
        vm.startBroadcast();

        address[] memory facets = new address[](5);
        facets[0] = address(new DiamondInspectFacet());
        facets[1] = address(new ERC20DataFacet());
        facets[2] = address(new ERC20ApproveFacet());
        facets[3] = address(new ERC20TransferFacet());
        facets[4] = address(new CanonicalStorageFacet());

        diamond = new Diamond(facets);
        vm.stopBroadcast();
    }
}
