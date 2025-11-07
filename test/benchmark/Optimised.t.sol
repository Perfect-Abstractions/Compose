// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Utils} from "./Utils.sol";
import {MinimalDiamond} from "./MinimalDiamond.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {InitShardedLoupe} from "../../src/diamond/InitShardedLoupe.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {ShardedDiamondLoupeFacet} from "../../src/diamond/ShardedDiamondLoupeFacet.sol";

contract OptimisedLoupeBenchmarkTest is Utils {
    struct GasMetrics {
        uint256 facets;
        uint256 facetFunctionSelectors;
        uint256 facetAddresses;
        uint256 facetAddress;
    }

    function testGas_CompareLoupe() external {
        GasMetrics memory baseline = _measure(false);
        GasMetrics memory sharded = _measure(true);

        emit log_string("=== facets() ===");
        emit log_named_uint("baseline", baseline.facets);
        emit log_named_uint("sharded", sharded.facets);
        assertLt(sharded.facets, baseline.facets);

        emit log_string("=== facetFunctionSelectors(address) ===");
        emit log_named_uint("baseline", baseline.facetFunctionSelectors);
        emit log_named_uint("sharded", sharded.facetFunctionSelectors);
        assertLt(sharded.facetFunctionSelectors, baseline.facetFunctionSelectors);

        emit log_string("=== facetAddresses() ===");
        emit log_named_uint("baseline", baseline.facetAddresses);
        emit log_named_uint("sharded", sharded.facetAddresses);
        assertLt(sharded.facetAddresses, baseline.facetAddresses);

        emit log_string("=== facetAddress(bytes4) ===");
        emit log_named_uint("baseline", baseline.facetAddress);
        emit log_named_uint("sharded", sharded.facetAddress);
    }

    function _measure(bool useSharded) internal returns (GasMetrics memory metrics) {
        (MinimalDiamond benchDiamond, address loupeAddr) = _setupDiamond(useSharded);

        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(benchDiamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        metrics.facets = startGas - gasleft();
        require(success, "facets() failed");
        if (useSharded) {
            ShardedDiamondLoupeFacet.Facet[] memory allFacets = abi.decode(data, (ShardedDiamondLoupeFacet.Facet[]));
            assertEq(allFacets.length, NUM_FACETS + 1);
        } else {
            DiamondLoupeFacet.Facet[] memory allFacets = abi.decode(data, (DiamondLoupeFacet.Facet[]));
            assertEq(allFacets.length, NUM_FACETS + 1);
        }

        startGas = gasleft();
        (success, data) = address(benchDiamond).call(
            abi.encodeWithSelector(SELECTOR_FACET_FUNCTION_SELECTORS, loupeAddr)
        );
        metrics.facetFunctionSelectors = startGas - gasleft();
        require(success, "facetFunctionSelectors() failed");
        bytes4[] memory facetSelectors = abi.decode(data, (bytes4[]));
        assertEq(facetSelectors.length, NUM_LOUPE_SELECTORS);

        startGas = gasleft();
        (success, data) = address(benchDiamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        metrics.facetAddresses = startGas - gasleft();
        require(success, "facetAddresses() failed");
        address[] memory allFacetAddresses = abi.decode(data, (address[]));
        assertEq(allFacetAddresses.length, NUM_FACETS + 1);

        startGas = gasleft();
        (success, data) = address(benchDiamond).call(
            abi.encodeWithSelector(SELECTOR_FACET_ADDRESS, SELECTOR_FACET_ADDRESSES)
        );
        metrics.facetAddress = startGas - gasleft();
        require(success, "facetAddress() failed");
        address facetAddr = abi.decode(data, (address));
        assertEq(facetAddr, loupeAddr);

        return metrics;
    }

    function _setupDiamond(bool useSharded)
        internal
        returns (MinimalDiamond benchDiamond, address loupeAddr)
    {
        benchDiamond = new MinimalDiamond();
        loupeAddr = useSharded ? address(new ShardedDiamondLoupeFacet()) : address(new DiamondLoupeFacet());

        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
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
        benchDiamond.initialize(dc, args);

        _buildDiamond(address(benchDiamond), NUM_FACETS, SELECTORS_PER_FACET);

        if (useSharded) {
            _enableShardedLoupe(benchDiamond);
        }
    }

    function _enableShardedLoupe(MinimalDiamond benchDiamond) internal {
        InitShardedLoupe initContract = new InitShardedLoupe();
        LibDiamond.FacetCut[] memory noCuts = new LibDiamond.FacetCut[](0);
        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({
            init: address(initContract),
            initCalldata: abi.encodeCall(InitShardedLoupe.init, ())
        });
        benchDiamond.initialize(noCuts, args);
    }
}
