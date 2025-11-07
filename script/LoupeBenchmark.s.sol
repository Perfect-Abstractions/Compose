// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {DiamondLoupeFacet} from "../src/diamond/DiamondLoupeFacet.sol";
import {MinimalDiamond} from "../test/benchmark/MinimalDiamond.sol";
import {LibDiamond} from "../src/diamond/LibDiamond.sol";
import {OriginalDiamondLoupeFacet} from "./loupeImplementations/OriginalDiamondLoupeFacet.sol";
import {TwoPassDiamondLoupeFacet} from "./loupeImplementations/TwoPassDiamondLoupeFacet.sol";
import {CollisionMapDiamondLoupeFacet} from "./loupeImplementations/CollisionMapDiamondLoupeFacet.sol";

import "./Utils.sol";

contract LoupeBenchmarkScript is Utils {
    struct Config {
        uint16 facets;
        uint16 selectors;
    }

    struct Impl {
        string name;
        address loupe;
    }

    Config[] public configs;
    Impl[] public impls;

    string constant CSV_FILE = "./benchmark.csv";

    function _run(bool huge_config) internal {
        

        // Init CSV file
        vm.writeLine(CSV_FILE, "Implementation,Function,Facets,Selectors,GasUsed");

        _init_implentations();
        _init_configs(huge_config);

        for (uint256 j = 0; j < impls.length; j++) {
            for (uint256 i = 0; i < configs.length; i++) {
                vm.startBroadcast();
                Config memory cfg = configs[i];
                Impl memory impl = impls[j];
                _run_test(impl.loupe, impl.name, cfg.facets, cfg.selectors);
                vm.stopBroadcast();
            }
        }

        
    }

    function run() external {
        _run(false);
    }

    function runWithHugeConfig() external {
        _run(true);
    }

    function _init_implentations() internal {
        // TODO: add more implementations
        impls.push(Impl("Current", address(new DiamondLoupeFacet())));
        impls.push(Impl("Original", address(new OriginalDiamondLoupeFacet())));
        impls.push(Impl("TwoPass", address(new TwoPassDiamondLoupeFacet())));
        impls.push(Impl("CollisionMap", address(new CollisionMapDiamondLoupeFacet())));
    }

    function _init_configs(bool huge_config) internal {
        // Test cases
        configs.push(Config(0, 0));
        configs.push(Config(1, 2));
        configs.push(Config(2, 4));
        configs.push(Config(3, 6));
        configs.push(Config(10, 40));
        configs.push(Config(20, 40));
        configs.push(Config(16, 64));
        configs.push(Config(32, 64));
        configs.push(Config(64, 64));
        configs.push(Config(42, 504));
        configs.push(Config(7, 20));
        configs.push(Config(17, 50));
        configs.push(Config(34, 100));
        configs.push(Config(167, 500));
        configs.push(Config(84, 1000));
        configs.push(Config(334, 1000));
        if (huge_config) {
            configs.push(Config(834, 10000));
            configs.push(Config(5000, 40000));
        }
    }

    function _run_test(address loupe, string memory name, uint256 nFacet, uint256 perFacet) internal {
        MinimalDiamond diamond = _createTest(loupe, nFacet, perFacet);

        uint256 gasStart = gasleft();
        (bool ok1,) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        uint256 gasUsed1 = gasStart - gasleft();
        string memory gasUsed1s;
        if (ok1) {
            gasUsed1s = vm.toString(gasUsed1);
        } else {
            gasUsed1s = "out of gas";
        }
        vm.writeLine(
            CSV_FILE, string.concat(name, ",facets(),", vm.toString(nFacet), ",", vm.toString(perFacet), ",", gasUsed1s)
        );

        gasStart = gasleft();
        (bool ok2,) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        uint256 gasUsed2 = gasStart - gasleft();
        string memory gasUsed2s;
        if (ok2) {
            gasUsed2s = vm.toString(gasUsed2);
        } else {
            gasUsed2s = "out of gas";
        }
        vm.writeLine(
            CSV_FILE,
            string.concat(name, ",facetAddresses(),", vm.toString(nFacet), ",", vm.toString(perFacet), ",", gasUsed2s)
        );
    }

    function _createTest(address loupe, uint256 nFacet, uint256 perFacet) internal returns (MinimalDiamond diamond) {
        diamond = new MinimalDiamond();

        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = SELECTOR_FACET_ADDRESS;

        LibDiamond.FacetCut[] memory dc = new LibDiamond.FacetCut[](1);

        LibDiamond.FacetCut;
        dc[0] = LibDiamond.FacetCut({
            facetAddress: loupe,
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});

        diamond.initialize(dc, args);

        _buildDiamond(address(diamond), nFacet, perFacet);
    }
}
