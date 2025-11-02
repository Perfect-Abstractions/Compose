// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {MinimalDiamond} from "./MinimalDiamond.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

contract LoupeGasBenchmarkTest is Test {
    MinimalDiamond internal diamond;
    DiamondLoupeFacet internal loupe;

    function setUp() public {
        loupe = new DiamondLoupeFacet();
        diamond = new MinimalDiamond();

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;

        LibDiamond.FacetCut[] memory dc = new LibDiamond.FacetCut[](1);

        dc[0] = LibDiamond.FacetCut({
            facetAddress: address(loupe),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});

        diamond.initialize(dc, args);
    }
}
