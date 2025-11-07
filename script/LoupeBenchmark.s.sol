// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {DiamondLoupeFacet} from "../src/diamond/DiamondLoupeFacet.sol";
import {MinimalDiamond} from "../test/benchmark/MinimalDiamond.sol";
import {LibDiamond} from "../src/diamond/LibDiamond.sol";

import "./Utils.sol";

contract LoupeBenchmarkScript is Utils {

    struct Config {
        uint16 facets;
        uint16 selectors;
    }

    Config[] public configs;

    string constant CSV_FILE = "./benchmark.csv";

    function _run(
        bool huge_config
    ) internal {
        vm.startBroadcast();

        address loupeImpl = address(new DiamondLoupeFacet());
        string memory name = "Original";
        vm.writeLine(CSV_FILE,"Implementation,Function,Facets,Selectors,GasUsed");

        // Test cases 
        configs.push(Config(0, 0));
        configs.push(Config(2, 1));
        configs.push(Config(4, 2));
        configs.push(Config(6, 3));
        configs.push(Config(40, 10));
        configs.push(Config(40, 20));
        configs.push(Config(64, 16));
        configs.push(Config(64, 32));
        configs.push(Config(64, 64));
        configs.push(Config(504, 42));
        configs.push(Config(20, 7));
        configs.push(Config(50, 17));
        configs.push(Config(100, 34));
        configs.push(Config(500, 167));
        configs.push(Config(1000, 84));
        configs.push(Config(1000, 334));
        if(huge_config) {
            configs.push(Config(10000, 834));
            configs.push(Config(40000, 5000));
        }
        for (uint256 i = 0; i < configs.length; i++) {
            Config memory cfg = configs[i];
            MinimalDiamond diamond = _createTest(loupeImpl, cfg.facets, cfg.selectors);

            uint256 gasStart = gasleft();
            (bool ok1,) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
            uint256 gasUsed1 = gasStart - gasleft();
            string memory gasUsed1s;
            if(ok1) {
                gasUsed1s = vm.toString(gasUsed1);
            } else {
                gasUsed1s = "out of gas";
            }
            vm.writeLine(CSV_FILE,string.concat(
                        name, ",facets(),",
                        vm.toString(cfg.facets), ",",
                        vm.toString(cfg.selectors), ",",
                        gasUsed1s
                    ));

            gasStart = gasleft();
            (bool ok2,) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
            uint256 gasUsed2 = gasStart - gasleft();
            string memory gasUsed2s;
            if(ok2) {
                gasUsed2s = vm.toString(gasUsed2);
            } else {
                gasUsed2s = "out of gas";
            }
            vm.writeLine(CSV_FILE,string.concat(
                        name, ",facetAddresses(),",
                        vm.toString(cfg.facets), ",",
                        vm.toString(cfg.selectors), ",",
                        gasUsed2s
                    ));
        }

        vm.stopBroadcast();
    }

    function run() external {
        _run(false);
    }

    function runWithHugeConfig() external {
        _run(true);
    }

    function _createTest(address loupe, uint256 nFacet, uint256 perFacet)
        internal
        returns (MinimalDiamond diamond)
    {
        diamond = new MinimalDiamond();

        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = SELECTOR_FACET_ADDRESS;

        LibDiamond.FacetCut[] memory dc = new LibDiamond.FacetCut[](1);

        LibDiamond.FacetCut ;
        dc[0] = LibDiamond.FacetCut({
            facetAddress: loupe,
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args =
            MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});

        diamond.initialize(dc, args);

        _buildDiamond(address(diamond), nFacet, perFacet);
    }

}