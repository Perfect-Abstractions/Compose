// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {MinimalDiamond} from "./MinimalDiamond.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {ShardedDiamondLoupeFacet} from "../../src/diamond/ShardedDiamondLoupeFacet.sol";
import {LibDiamondShard} from "../../src/diamond/LibDiamondShard.sol";
import {InitShardedLoupe} from "../../src/diamond/InitShardedLoupe.sol";

/// @title ShardedLoupeBenchmark
/// @notice Comprehensive benchmarks comparing baseline vs sharded loupe across multiple configurations
contract ShardedLoupeBenchmark is Test {
    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");
    bytes32 constant SHARDED_LOUPE_STORAGE_POSITION = keccak256("compose.sharded.loupe");
    
    bytes4 constant SELECTOR_FACETS = bytes4(keccak256("facets()"));
    bytes4 constant SELECTOR_FACET_FUNCTION_SELECTORS = bytes4(keccak256("facetFunctionSelectors(address)"));
    bytes4 constant SELECTOR_FACET_ADDRESSES = bytes4(keccak256("facetAddresses()"));
    bytes4 constant SELECTOR_FACET_ADDRESS = bytes4(keccak256("facetAddress(bytes4)"));

    struct TestConfig {
        uint256 numFacets;
        uint256 selectorsPerFacet;
        string name;
    }

    /*//////////////////////////////////////////////////////////////
                            STORAGE HELPERS
    //////////////////////////////////////////////////////////////*/

    function _facetAndPositionsSlot(bytes4 selector) internal pure returns (bytes32) {
        return keccak256(abi.encode(selector, DIAMOND_STORAGE_POSITION));
    }

    function _packFacetAndPosition(address facet, uint16 position) internal pure returns (bytes32) {
        return bytes32((uint256(uint160(facet))) | (uint256(position) << 160));
    }

    function _storeFacetAndPosition(address account, bytes4 selector, address facet, uint16 position) internal {
        vm.store(account, _facetAndPositionsSlot(selector), _packFacetAndPosition(facet, position));
    }

    function _selectorsLengthSlot() internal pure returns (bytes32) {
        return bytes32(uint256(DIAMOND_STORAGE_POSITION) + 1);
    }

    function _selectorsDataBase() internal pure returns (bytes32) {
        return keccak256(abi.encode(uint256(DIAMOND_STORAGE_POSITION) + 1));
    }

    function _storeSelectorAtIndex(address account, bytes4 selector, uint256 index) internal {
        bytes32 base = _selectorsDataBase();
        uint256 packedWordIndex = index / 8;
        uint256 laneIndex = index % 8;
        bytes32 packedWordSlot = bytes32(uint256(base) + packedWordIndex);

        bytes32 oldPackedWord = vm.load(account, packedWordSlot);

        uint256 laneShiftBits = laneIndex * 32;
        uint256 clearLaneMask = ~(uint256(0xffffffff) << laneShiftBits);
        uint256 laneInsertBits = (uint256(uint32(selector)) << laneShiftBits);
        uint256 newPackedWord = (uint256(oldPackedWord) & clearLaneMask) | laneInsertBits;

        vm.store(account, packedWordSlot, bytes32(newPackedWord));
    }

    function _buildDiamond(address account, uint256 nFacets, uint256 perFacet) internal {
        uint256 total = nFacets * perFacet;
        vm.store(account, _selectorsLengthSlot(), bytes32(total));

        uint256 globalIndex;
        for (uint256 f = 0; f < nFacets; f++) {
            address facet = _facetAddr(f);
            for (uint16 j = 0; j < perFacet; j++) {
                bytes4 selector = _selectorFor(f, j);
                _storeSelectorAtIndex(account, selector, globalIndex);
                _storeFacetAndPosition(account, selector, facet, j);
                unchecked {
                    ++globalIndex;
                }
            }
        }
    }

    function _facetAddr(uint256 f) internal returns (address) {
        return makeAddr(string.concat("facet_", vm.toString(f)));
    }

    function _selectorFor(uint256 f, uint16 j) internal pure returns (bytes4) {
        // Efficient deterministic selector generation using bit packing
        // This avoids string concatenation and hashing overhead
        return bytes4(keccak256(abi.encodePacked(uint256(f), uint256(j))));
    }

    function _enableShardedLoupe(address diamond) internal {
        // Deploy and call the init contract to enable sharded loupe
        InitShardedLoupe initContract = new InitShardedLoupe();
        (bool success,) = diamond.call(abi.encodeWithSelector(initContract.init.selector));
        require(success, "Failed to enable sharded loupe");
    }

    /*//////////////////////////////////////////////////////////////
                         BENCHMARK TESTS
    //////////////////////////////////////////////////////////////*/

    function _runBenchmark(TestConfig memory config, bool useSharded) internal {
        emit log_string("");
        emit log_string(string.concat("=== ", config.name, useSharded ? " (Sharded)" : " (Baseline)", " ==="));
        emit log_string(string.concat("Facets: ", vm.toString(config.numFacets)));
        emit log_string(string.concat("Selectors per facet: ", vm.toString(config.selectorsPerFacet)));
        emit log_string(string.concat("Total selectors: ", vm.toString(config.numFacets * config.selectorsPerFacet)));
        
        MinimalDiamond diamond = new MinimalDiamond();
        address loupeAddr;
        
        if (useSharded) {
            loupeAddr = address(new ShardedDiamondLoupeFacet());
        } else {
            loupeAddr = address(new DiamondLoupeFacet());
        }

        // Initialize loupe facet
        bytes4[] memory loupeSelectors = new bytes4[](4);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = SELECTOR_FACET_ADDRESS;

        LibDiamond.FacetCut[] memory dc = new LibDiamond.FacetCut[](1);
        dc[0] = LibDiamond.FacetCut({
            facetAddress: loupeAddr,
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});
        diamond.initialize(dc, args);

        // Build diamond storage
        _buildDiamond(address(diamond), config.numFacets, config.selectorsPerFacet);
        
        if (useSharded) {
            _enableShardedLoupe(address(diamond));
        }

        // Benchmark facets()
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        uint256 facetsGas = startGas - gasleft();
        require(success, "facets() failed");
        emit log_named_uint("facets() gas", facetsGas);

        // Benchmark facetAddresses()
        startGas = gasleft();
        (success, data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        uint256 addressesGas = startGas - gasleft();
        require(success, "facetAddresses() failed");
        emit log_named_uint("facetAddresses() gas", addressesGas);

        // Benchmark facetFunctionSelectors()
        startGas = gasleft();
        (success, data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_FUNCTION_SELECTORS, loupeAddr));
        uint256 selectorsGas = startGas - gasleft();
        require(success, "facetFunctionSelectors() failed");
        emit log_named_uint("facetFunctionSelectors() gas", selectorsGas);

        // Benchmark facetAddress()
        startGas = gasleft();
        (success, data) = address(diamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESS, SELECTOR_FACETS));
        uint256 addressGas = startGas - gasleft();
        require(success, "facetAddress() failed");
        emit log_named_uint("facetAddress() gas", addressGas);
    }

    /// @notice Benchmark: 64 facets, 16 selectors each (1,024 total)
    function testBenchmark_64_16_Baseline() external {
        _runBenchmark(TestConfig({numFacets: 64, selectorsPerFacet: 16, name: "64x16"}), false);
    }

    function testBenchmark_64_16_Sharded() external {
        _runBenchmark(TestConfig({numFacets: 64, selectorsPerFacet: 16, name: "64x16"}), true);
    }

    /// @notice Benchmark: 64 facets, 64 selectors each (4,096 total)
    function testBenchmark_64_64_Baseline() external {
        _runBenchmark(TestConfig({numFacets: 64, selectorsPerFacet: 64, name: "64x64"}), false);
    }

    function testBenchmark_64_64_Sharded() external {
        _runBenchmark(TestConfig({numFacets: 64, selectorsPerFacet: 64, name: "64x64"}), true);
    }

    /// @notice Benchmark: 1,000 facets, 84 selectors each (84,000 total)
    function testBenchmark_1k_84_Baseline() external {
        _runBenchmark(TestConfig({numFacets: 1000, selectorsPerFacet: 84, name: "1kx84"}), false);
    }

    function testBenchmark_1k_84_Sharded() external {
        _runBenchmark(TestConfig({numFacets: 1000, selectorsPerFacet: 84, name: "1kx84"}), true);
    }

    /// @notice Benchmark: 10,000 facets, 834 selectors each (8,340,000 total) - might be too large
    function testBenchmark_10k_834_Baseline() external {
        _runBenchmark(TestConfig({numFacets: 10000, selectorsPerFacet: 834, name: "10kx834"}), false);
    }

    function testBenchmark_10k_834_Sharded() external {
        _runBenchmark(TestConfig({numFacets: 10000, selectorsPerFacet: 834, name: "10kx834"}), true);
    }

    /// @notice Benchmark: 40,000 facets, 5,000 selectors each - smoke test (might be too large)
    function testBenchmark_40k_5k_Baseline() external {
        _runBenchmark(TestConfig({numFacets: 40000, selectorsPerFacet: 5000, name: "40kx5k"}), false);
    }

    function testBenchmark_40k_5k_Sharded() external {
        _runBenchmark(TestConfig({numFacets: 40000, selectorsPerFacet: 5000, name: "40kx5k"}), true);
    }
}
