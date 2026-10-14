// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {DiamondUpgradeFacet} from "@perfect-abstractions/compose/diamond/DiamondUpgradeFacet.sol";
import {HistoryDiamond} from "../src/HistoryDiamond.sol";
import {
    HistoryFacetA,
    HistoryFacetB,
    HistoryFacetB2,
    HistoryFacetC,
    HistoryInitializer
} from "../src/HistoryFacets.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        DiamondUpgradeFacet upgradeFacet = new DiamondUpgradeFacet();
        HistoryDiamond diamond = new HistoryDiamond(address(upgradeFacet));
        HistoryFacetA facetA = new HistoryFacetA();
        HistoryFacetB facetB = new HistoryFacetB();
        HistoryFacetC facetC = new HistoryFacetC();
        HistoryFacetB2 facetB2 = new HistoryFacetB2();
        HistoryInitializer initializer = new HistoryInitializer();

        address[] memory additions = new address[](1);
        address[] memory noFacets = new address[](0);
        DiamondUpgradeFacet.FacetReplacement[] memory noReplacements = new DiamondUpgradeFacet.FacetReplacement[](0);

        additions[0] = address(facetA);
        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(additions, noReplacements, noFacets, address(0), "", bytes32(0), "");

        additions[0] = address(facetB);
        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(additions, noReplacements, noFacets, address(0), "", bytes32(0), "");

        additions[0] = address(facetC);
        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(additions, noReplacements, noFacets, address(0), "", bytes32(0), "");

        DiamondUpgradeFacet.FacetReplacement[] memory replacements = new DiamondUpgradeFacet.FacetReplacement[](1);
        replacements[0] = DiamondUpgradeFacet.FacetReplacement(address(facetB), address(facetB2));
        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(noFacets, replacements, noFacets, address(0), "", bytes32(0), "");

        address[] memory removals = new address[](1);
        removals[0] = address(facetC);
        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(noFacets, noReplacements, removals, address(0), "", bytes32(0), "");

        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(noFacets, noReplacements, noFacets, address(0), "", bytes32("history"), hex"1234");

        DiamondUpgradeFacet(address(diamond))
            .upgradeDiamond(
                noFacets,
                noReplacements,
                noFacets,
                address(initializer),
                abi.encodeWithSelector(HistoryInitializer.initialize.selector),
                bytes32(0),
                ""
            );

        vm.stopBroadcast();
    }
}
