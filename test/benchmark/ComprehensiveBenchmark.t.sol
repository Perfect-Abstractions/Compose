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
import {JackieXuDiamondLoupeFacet} from "./implementations/JackieXuDiamondLoupeFacet.sol";
import {KitetsuDineshDiamondLoupeFacet} from "./implementations/KitetsuDineshDiamondLoupeFacet.sol";
import {Dawid919DiamondLoupeFacet} from "./implementations/Dawid919DiamondLoupeFacet.sol";

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
        bool facetsSuccess;
        bool facetAddressesSuccess;
    }

    Result[] internal results;
    bool internal constant VERBOSE_LOGS = false;

    event BenchmarkResult(
        string indexed implementation,
        uint256 numSelectors,
        uint256 numFacets,
        uint256 facetsGas,
        uint256 facetAddressesGas,
        bool facetsSuccess,
        bool facetAddressesSuccess
    );

    struct CallOutcome {
        bool success;
        uint256 gasUsed;
    }

    struct ImplementationConfig {
        string name;
        address loupe;
        bool supportsLargeConfigurations;
    }

    uint256 internal constant CALL_GAS_BUFFER = 200_000;
    uint256 internal constant MAX_BENCHMARK_CALL_GAS = 250_000_000;
    uint256 internal constant LARGE_CONFIG_THRESHOLD = 2_000;

    function _boolToString(bool value) internal pure returns (string memory) {
        return value ? "1" : "0";
    }

    function _logResult(
        string memory implName,
        uint256 numSelectors,
        uint256 numFacets,
        bool facetsSuccess,
        uint256 facetsGas,
        bool facetAddressesSuccess,
        uint256 facetAddressesGas
    ) internal {
        console2.log(
            string(
                abi.encodePacked(
                    "BENCHMARK_RESULT,",
                    implName,
                    ",",
                    vm.toString(numSelectors),
                    ",",
                    vm.toString(numFacets),
                    ",",
                    _boolToString(facetsSuccess),
                    ",",
                    vm.toString(facetsGas),
                    ",",
                    _boolToString(facetAddressesSuccess),
                    ",",
                    vm.toString(facetAddressesGas)
                )
            )
        );
    }

    function _executeLoupeCall(bytes4 selector) internal returns (CallOutcome memory outcome) {
        uint256 startGas = gasleft();
        uint256 buffer = CALL_GAS_BUFFER;
        if (startGas <= buffer) {
            buffer = startGas / 10;
        }
        uint256 gasToAllocate = startGas - buffer;
        if (gasToAllocate > MAX_BENCHMARK_CALL_GAS) {
            gasToAllocate = MAX_BENCHMARK_CALL_GAS;
        }
        (bool success,) = address(diamond).call{gas: gasToAllocate}(abi.encodeWithSelector(selector));
        uint256 gasUsed = startGas - gasleft();
        outcome = CallOutcome({success: success, gasUsed: gasUsed});
    }

    function _recordSkip(string memory implName, uint256 numSelectors, uint256 numFacets) internal {
        emit BenchmarkResult(implName, numSelectors, numFacets, 0, 0, false, false);

        _logResult(implName, numSelectors, numFacets, false, 0, false, 0);

        if (VERBOSE_LOGS) {
            console2.log("BENCHMARK_RESULT:");
            console2.log("  Implementation: %s", implName);
            console2.log("  Selectors: %s", vm.toString(numSelectors));
            console2.log("  Facets: %s", vm.toString(numFacets));
            console2.log("  SKIPPED: configuration exceeds supported size");
            console2.log("");
        }

        results.push(
            Result({
                implementation: implName,
                numSelectors: numSelectors,
                numFacets: numFacets,
                facetsGas: 0,
                facetAddressesGas: 0,
                facetsSuccess: false,
                facetAddressesSuccess: false
            })
        );
    }

    function _runImplementationSet(
        ImplementationConfig[] memory implementations,
        uint256 numSelectors,
        uint256 numFacets
    ) internal {
        for (uint256 implIndex; implIndex < implementations.length; implIndex++) {
            ImplementationConfig memory config = implementations[implIndex];
            if (numSelectors > LARGE_CONFIG_THRESHOLD && !config.supportsLargeConfigurations) {
                _recordSkip(config.name, numSelectors, numFacets);
                continue;
            }
            _benchmarkImplementation(config.name, config.loupe, numSelectors, numFacets);
        }
    }

    function _defaultImplementations() internal returns (ImplementationConfig[] memory implementations) {
        implementations = new ImplementationConfig[](7);
        implementations[0] = ImplementationConfig("Original", address(new OriginalDiamondLoupeFacet()), false);
        implementations[1] = ImplementationConfig("ComposeReference", address(new DiamondLoupeFacet()), true);
        implementations[2] = ImplementationConfig("TwoPassBaseline", address(new TwoPassDiamondLoupeFacet()), false);
        implementations[3] = ImplementationConfig("CollisionMap", address(new CollisionMapDiamondLoupeFacet()), false);
        implementations[4] = ImplementationConfig("JackieXu", address(new JackieXuDiamondLoupeFacet()), true);
        implementations[5] = ImplementationConfig("KitetsuDinesh", address(new KitetsuDineshDiamondLoupeFacet()), false);
        implementations[6] = ImplementationConfig("Dawid919", address(new Dawid919DiamondLoupeFacet()), false);
    }

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

        CallOutcome memory facetsOutcome = _executeLoupeCall(SELECTOR_FACETS);
        CallOutcome memory facetAddressesOutcome = _executeLoupeCall(SELECTOR_FACET_ADDRESSES);

        emit BenchmarkResult(
            implName,
            numSelectors,
            numFacets,
            facetsOutcome.gasUsed,
            facetAddressesOutcome.gasUsed,
            facetsOutcome.success,
            facetAddressesOutcome.success
        );

        _logResult(
            implName,
            numSelectors,
            numFacets,
            facetsOutcome.success,
            facetsOutcome.gasUsed,
            facetAddressesOutcome.success,
            facetAddressesOutcome.gasUsed
        );

        if (VERBOSE_LOGS) {
            console2.log("BENCHMARK_RESULT:");
            console2.log("  Implementation: %s", implName);
            console2.log("  Selectors: %s", vm.toString(numSelectors));
            console2.log("  Facets: %s", vm.toString(numFacets));
            if (facetsOutcome.success) {
                console2.log("  facets() gas: %s", vm.toString(facetsOutcome.gasUsed));
            } else {
                console2.log("  facets() FAILED");
            }
            if (facetAddressesOutcome.success) {
                console2.log("  facetAddresses() gas: %s", vm.toString(facetAddressesOutcome.gasUsed));
            } else {
                console2.log("  facetAddresses() FAILED");
            }
            console2.log("");
        }

        results.push(
            Result({
                implementation: implName,
                numSelectors: numSelectors,
                numFacets: numFacets,
                facetsGas: facetsOutcome.gasUsed,
                facetAddressesGas: facetAddressesOutcome.gasUsed,
                facetsSuccess: facetsOutcome.success,
                facetAddressesSuccess: facetAddressesOutcome.success
            })
        );
    }

    function _runIssue155Configurations(uint256 start, uint256 end) internal {
        ImplementationConfig[] memory implementations = _defaultImplementations();

        uint256[10] memory selectorOptions = [uint256(0), 2, 4, 6, 40, 40, 64, 64, 64, 504];
        uint256[10] memory facetOptions = [uint256(0), 1, 2, 3, 10, 20, 16, 32, 64, 42];

        for (uint256 i = start; i < end; i++) {
            _runImplementationSet(implementations, selectorOptions[i], facetOptions[i]);
        }
    }

    // Test configurations from issue #155 (first half)
    function test_Issue155Configurations_Part1() public {
        _runIssue155Configurations(0, 5);
    }

    // Test configurations from issue #155 (second half)
    function test_Issue155Configurations_Part2A() public {
        _runIssue155Configurations(5, 8);
    }

    function test_Issue155Configurations_Part2B() public {
        _runIssue155Configurations(8, 10);
    }

    function _runExtendedConfigurations(uint256 index) internal {
        ImplementationConfig[] memory implementations = _defaultImplementations();
        uint256[3] memory selectors = [uint256(1000), uint256(10000), uint256(12000)];
        uint256[3] memory facets = [uint256(84), uint256(834), uint256(1200)];
        _runImplementationSet(implementations, selectors[index], facets[index]);
    }

    // Extended configurations for comprehensive testing
    function test_ExtendedConfigurations_Tier1() public {
        _runExtendedConfigurations(0);
    }

    function test_ExtendedConfigurations_Tier2() public {
        _runExtendedConfigurations(1);
    }

    function test_ExtendedConfigurations_Tier3() public {
        _runExtendedConfigurations(2);
    }

    // Additional configurations mentioned in issue #155
    function _runAdditionalConfiguration(uint256 index) internal {
        ImplementationConfig[] memory implementations = _defaultImplementations();
        uint256[5] memory selectors = [uint256(20), uint256(50), uint256(100), uint256(500), uint256(1000)];
        uint256[5] memory facets = [uint256(7), uint256(17), uint256(34), uint256(167), uint256(334)];
        _runImplementationSet(implementations, selectors[index], facets[index]);
    }

    function test_AdditionalConfigurations_Tier1() public {
        _runAdditionalConfiguration(0);
    }

    function test_AdditionalConfigurations_Tier2() public {
        _runAdditionalConfiguration(1);
    }

    function test_AdditionalConfigurations_Tier3() public {
        _runAdditionalConfiguration(2);
    }

    function test_AdditionalConfigurations_Tier4() public {
        _runAdditionalConfiguration(3);
    }

    function test_AdditionalConfigurations_Tier5() public {
        _runAdditionalConfiguration(4);
    }
}

