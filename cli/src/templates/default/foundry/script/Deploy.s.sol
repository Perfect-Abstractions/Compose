// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {CounterFacet} from "../src/facets/CounterFacet.sol";
import {Diamond} from "../src/Diamond.sol";
import {DiamondInspectFacet} from "@perfect-abstractions/compose/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "@perfect-abstractions/compose/diamond/DiamondUpgradeFacet.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        CounterFacet counterFacet = new CounterFacet();
        DiamondInspectFacet inspectFacet = new DiamondInspectFacet();
        DiamondUpgradeFacet upgradeFacet = new DiamondUpgradeFacet();

        address[] memory facets = new address[](3);
        facets[0] = address(counterFacet);
        facets[1] = address(inspectFacet);
        facets[2] = address(upgradeFacet);

        new Diamond(facets, msg.sender);

        vm.stopBroadcast();
    }
}
