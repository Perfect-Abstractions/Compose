// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {Utils} from "./Utils.sol";
import {MinimalDiamond} from "./MinimalDiamond.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {OriginalDiamondLoupeFacet} from "./implementations/OriginalDiamondLoupeFacet.sol";
import {TwoPassDiamondLoupeFacet} from "./implementations/TwoPassDiamondLoupeFacet.sol";
import {CollisionMapDiamondLoupeFacet} from "./implementations/CollisionMapDiamondLoupeFacet.sol";

/// @title Comprehensive Diamond Loupe Gas Benchmark
/// @notice Tests multiple implementations with various selector/facet configurations
/// @dev Generates gas reports for facets() and facetAddresses() functions
contract ComprehensiveLoupeBenchmark is Utils {
    MinimalDiamond internal diamond;
    address internal loupe;

    struct Result {
        string implementation;
        uint256 numSelectors;
        uint256 numFacets;
        uint256 facetsGas;
        uint256 facetAddressesGas;
    }

    Result[] internal results;

    event BenchmarkResult(
        string indexed implementation,
        uint256 numSelectors,
        uint256 numFacets,
        uint256 facetsGas,
        uint256 facetAddressesGas
    );

    function _setupDiamond(address loupeAddress, uint256 numFacets, uint256 selectorsPerFacet) internal {
        diamond = new MinimalDiamond();
        loupe = loupeAddress;

        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = bytes4(keccak256("facetFunctionSelectors(address)"));
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = bytes4(keccak256("facetAddress(bytes4)"));

        LibDiamond.FacetCut[] memory dc = new LibDiamond.FacetCut[](1);
        dc[0] = LibDiamond.FacetCut({
            facetAddress: loupe, action: LibDiamond.FacetCutAction.Add, functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});
        diamond.initialize(dc, args);

        _buildDiamond(address(diamond), numFacets, selectorsPerFacet);
    }

    function _benchmarkImplementation(
        string memory implName,
        address loupeAddress,
        uint256 numSelectors,
        uint256 numFacets
    ) internal {
        uint256 selectorsPerFacet;
        if (numFacets == 0) {
            selectorsPerFacet = 0;
        } else {
            selectorsPerFacet = numSelectors / numFacets;
            if (selectorsPerFacet == 0) selectorsPerFacet = 1;
        }

        _setupDiamond(loupeAddress, numFacets, selectorsPerFacet);

        // Benchmark facets()
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        uint256 facetsGas = startGas - gasleft();
        require(success, "facets() call failed");

        // Benchmark facetAddresses()
        startGas = gasleft();
        (success, data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        uint256 facetAddressesGas = startGas - gasleft();
        require(success, "facetAddresses() call failed");

        emit BenchmarkResult(implName, numSelectors, numFacets, facetsGas, facetAddressesGas);

        // Output results in parseable format
        console2.log("BENCHMARK_RESULT:");
        console2.log("  Implementation: %s", implName);
        console2.log("  Selectors: %s", vm.toString(numSelectors));
        console2.log("  Facets: %s", vm.toString(numFacets));
        console2.log("  facets() gas: %s", vm.toString(facetsGas));
        console2.log("  facetAddresses() gas: %s", vm.toString(facetAddressesGas));
        console2.log("");

        results.push(
            Result({
                implementation: implName,
                numSelectors: numSelectors,
                numFacets: numFacets,
                facetsGas: facetsGas,
                facetAddressesGas: facetAddressesGas
            })
        );
    }

    // Test configurations from issue #155
    function test_Original_AllConfigurations() public {
        address originalLoupe = address(new OriginalDiamondLoupeFacet());

        _benchmarkImplementation("Original", originalLoupe, 0, 0);
        _benchmarkImplementation("Original", originalLoupe, 2, 1);
        _benchmarkImplementation("Original", originalLoupe, 4, 2);
        _benchmarkImplementation("Original", originalLoupe, 6, 3);
        _benchmarkImplementation("Original", originalLoupe, 40, 10);
        _benchmarkImplementation("Original", originalLoupe, 40, 20);
        _benchmarkImplementation("Original", originalLoupe, 64, 16);
        _benchmarkImplementation("Original", originalLoupe, 64, 32);
        _benchmarkImplementation("Original", originalLoupe, 64, 64);
        _benchmarkImplementation("Original", originalLoupe, 504, 42);
    }

    function test_Current_AllConfigurations() public {
        address currentLoupe = address(new DiamondLoupeFacet());

        _benchmarkImplementation("Current", currentLoupe, 0, 0);
        _benchmarkImplementation("Current", currentLoupe, 2, 1);
        _benchmarkImplementation("Current", currentLoupe, 4, 2);
        _benchmarkImplementation("Current", currentLoupe, 6, 3);
        _benchmarkImplementation("Current", currentLoupe, 40, 10);
        _benchmarkImplementation("Current", currentLoupe, 40, 20);
        _benchmarkImplementation("Current", currentLoupe, 64, 16);
        _benchmarkImplementation("Current", currentLoupe, 64, 32);
        _benchmarkImplementation("Current", currentLoupe, 64, 64);
        _benchmarkImplementation("Current", currentLoupe, 504, 42);
    }

    function test_CollisionMap_AllConfigurations() public {
        address collisionMapLoupe = address(new CollisionMapDiamondLoupeFacet());

        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 0, 0);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 2, 1);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 4, 2);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 6, 3);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 40, 10);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 40, 20);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 64, 16);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 64, 32);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 64, 64);
        _benchmarkImplementation("CollisionMap", collisionMapLoupe, 504, 42);
    }

    function test_TwoPass_AllConfigurations() public {
        address twoPassLoupe = address(new TwoPassDiamondLoupeFacet());

        _benchmarkImplementation("TwoPass", twoPassLoupe, 0, 0);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 2, 1);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 4, 2);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 6, 3);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 40, 10);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 40, 20);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 64, 16);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 64, 32);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 64, 64);
        _benchmarkImplementation("TwoPass", twoPassLoupe, 504, 42);
    }

    // Extended configurations for comprehensive testing
    function test_ExtendedConfigurations() public {
        address originalLoupe = address(new OriginalDiamondLoupeFacet());
        address currentLoupe = address(new DiamondLoupeFacet());
        address twoPassLoupe = address(new TwoPassDiamondLoupeFacet());
        address collisionMapLoupe = address(new CollisionMapDiamondLoupeFacet());

        uint256[3][2] memory configs =
            [[uint256(1000), uint256(10000), uint256(40000)], [uint256(84), uint256(834), uint256(5000)]];

        for (uint256 i; i < 3; i++) {
            uint256 numSelectors = configs[0][i];
            uint256 numFacets = configs[1][i];

            _benchmarkImplementation("Original", originalLoupe, numSelectors, numFacets);
            _benchmarkImplementation("Current", currentLoupe, numSelectors, numFacets);
            _benchmarkImplementation("TwoPass", twoPassLoupe, numSelectors, numFacets);
            _benchmarkImplementation("CollisionMap", collisionMapLoupe, numSelectors, numFacets);
        }
    }

    // Additional configurations mentioned in issue #155
    function test_AdditionalConfigurations() public {
        address originalLoupe = address(new OriginalDiamondLoupeFacet());
        address currentLoupe = address(new DiamondLoupeFacet());
        address twoPassLoupe = address(new TwoPassDiamondLoupeFacet());
        address collisionMapLoupe = address(new CollisionMapDiamondLoupeFacet());

        uint256[5][2] memory configs = [
            [uint256(20), uint256(50), uint256(100), uint256(500), uint256(1000)],
            [uint256(7), uint256(17), uint256(34), uint256(167), uint256(334)]
        ];

        for (uint256 i; i < 5; i++) {
            uint256 numSelectors = configs[0][i];
            uint256 numFacets = configs[1][i];

            _benchmarkImplementation("Original", originalLoupe, numSelectors, numFacets);
            _benchmarkImplementation("Current", currentLoupe, numSelectors, numFacets);
            _benchmarkImplementation("TwoPass", twoPassLoupe, numSelectors, numFacets);
            _benchmarkImplementation("CollisionMap", collisionMapLoupe, numSelectors, numFacets);
        }
    }
}

