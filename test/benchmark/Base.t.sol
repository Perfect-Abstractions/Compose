// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Utils} from "@compose-benchmark/Utils.sol";

import {MinimalDiamond} from "@compose-benchmark/MinimalDiamond.sol";
import {Diamond} from "@compose/Diamond.sol";

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

        Diamond.FacetCut[] memory dc = new Diamond.FacetCut[](1);

        dc[0] = Diamond.FacetCut({
            facetAddress: loupe, action: Diamond.FacetCutAction.Add, functionSelectors: loupeSelectors
        });

        diamond.initialize(dc, address(0), "");

        /**
         * Initiatlise complex storage for minimal diamond
         */
        _buildDiamond(address(diamond), NUM_FACETS, SELECTORS_PER_FACET);
    }

    function _deployLoupe() internal virtual returns (address);
}
