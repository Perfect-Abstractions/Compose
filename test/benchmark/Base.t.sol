// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Utils} from "./Utils.sol";

import {MinimalDiamond} from "./MinimalDiamond.sol";
import "../../src/diamond/DiamondCut.sol" as DiamondCut;
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

abstract contract BaseBenchmark is Utils {
    MinimalDiamond internal diamond;
    address internal loupe;

    function setUp() public {
        diamond = new MinimalDiamond();
        loupe = _deployLoupe();

        /**
         * Initialize minimal diamond with DiamondLoupeFacet address and selectors.
         */
        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = SELECTOR_FACET_ADDRESS;

        DiamondCut.FacetCut[] memory dc = new DiamondCut.FacetCut[](1);

        dc[0] = DiamondCut.FacetCut({
            facetAddress: loupe, action: DiamondCut.FacetCutAction.Add, functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});

        diamond.initialize(dc, args);

        /**
         * Initiatlise complex storage for minimal diamond
         */
        _buildDiamond(address(diamond), NUM_FACETS, SELECTORS_PER_FACET);
    }

    function _deployLoupe() internal virtual returns (address);
}
