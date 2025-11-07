// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Utils} from "./Utils.sol";
import {MinimalDiamond} from "./MinimalDiamond.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {InitShardedLoupe} from "../../src/diamond/InitShardedLoupe.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";
import {ShardedDiamondLoupeFacet} from "../../src/diamond/ShardedDiamondLoupeFacet.sol";

/// @notice Produces Markdown gas tables for different loupe configurations
contract LoupeGasTableTest is Utils {
    struct GasMetrics {
        uint256 facets;
        uint256 facetAddresses;
    }

    struct Configuration {
        uint256 selectors;
        uint256 facets;
    }

    function testPrintLoupeGasTable() external {
        Configuration[] memory configs = _configs();

        emit log_string("| selectors/facets | baseline facets() | sharded facets() | baseline facetAddresses() | sharded facetAddresses() |");
        emit log_string("| --- | ---: | ---: | ---: | ---: |");

        for (uint256 i; i < configs.length; i++) {
            Configuration memory cfg = configs[i];
            _printRow(cfg.selectors, cfg.facets);
        }
    }

    function testPrintCustomRow() external {
        if (!vm.envOr("LOUPE_ROW_ENABLED", false)) {
            return;
        }

        uint256 selectors = vm.envOr("LOUPE_ROW_SELECTORS", uint256(0));
        uint256 facets = vm.envOr("LOUPE_ROW_FACETS", uint256(0));
        _printRow(selectors, facets);
    }

    function _printRow(uint256 selectorCount, uint256 facetCount) internal {
        string memory label = string.concat(vm.toString(selectorCount), "/", vm.toString(facetCount));
        GasMetrics memory baseline = _measure(false, selectorCount, facetCount, label);
        GasMetrics memory sharded = _measure(true, selectorCount, facetCount, label);

        emit log_string(
            string.concat(
                "| ",
                label,
                " | ",
                vm.toString(baseline.facets),
                " | ",
                vm.toString(sharded.facets),
                " | ",
                vm.toString(baseline.facetAddresses),
                " | ",
                vm.toString(sharded.facetAddresses),
                " |"
            )
        );
    }

    function _measure(bool useSharded, uint256 selectorCount, uint256 facetCount, string memory label)
        internal
        returns (GasMetrics memory metrics)
    {
        MinimalDiamond benchDiamond = _deployLoupe(useSharded);
        _populateSelectors(address(benchDiamond), selectorCount, facetCount);

        if (useSharded) {
            _enableShardedLoupe(benchDiamond);
        }

        uint256 startGas;
        bool success;
        bytes memory data;
        uint256 gasUsed;

        startGas = gasleft();
        (success, data) = address(benchDiamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        gasUsed = startGas - gasleft();
        string memory mode = useSharded ? "sharded" : "baseline";

        require(success, string.concat("facets() failed for ", mode, " configuration ", label));
        metrics.facets = gasUsed;
        uint256 facetsLength = _decodeArrayLength(data);
        assertEq(facetsLength, facetCount + 1, "unexpected facets length");

        startGas = gasleft();
        (success, data) = address(benchDiamond).call(abi.encodeWithSelector(SELECTOR_FACET_ADDRESSES));
        gasUsed = startGas - gasleft();
        require(success, string.concat("facetAddresses() failed for ", mode, " configuration ", label));
        metrics.facetAddresses = gasUsed;
        uint256 addressesLength = _decodeArrayLength(data);
        assertEq(addressesLength, facetCount + 1, "unexpected address count");

        return metrics;
    }

    function _deployLoupe(bool useSharded) internal returns (MinimalDiamond benchDiamond) {
        benchDiamond = new MinimalDiamond();
        address loupeAddr = useSharded ? address(new ShardedDiamondLoupeFacet()) : address(new DiamondLoupeFacet());

        LibDiamond.FacetCut[] memory cuts = new LibDiamond.FacetCut[](1);
        bytes4[] memory selectors = new bytes4[](NUM_LOUPE_SELECTORS);
        selectors[0] = SELECTOR_FACETS;
        selectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        selectors[2] = SELECTOR_FACET_ADDRESSES;
        selectors[3] = SELECTOR_FACET_ADDRESS;

        cuts[0] = LibDiamond.FacetCut({
            facetAddress: loupeAddr,
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: selectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});
        benchDiamond.initialize(cuts, args);
    }

    function _decodeArrayLength(bytes memory encoded) internal pure returns (uint256 length) {
        if (encoded.length < 0x40) {
            return 0;
        }

        assembly {
            length := mload(add(encoded, 0x40))
        }
    }

    function _populateSelectors(address account, uint256 selectorCount, uint256 facetCount) internal {
        uint256 totalLength = selectorCount + NUM_LOUPE_SELECTORS;
        vm.store(account, _selectorsLengthSlot(), bytes32(totalLength));

        if (selectorCount == 0 || facetCount == 0) {
            return;
        }

        uint256 basePerFacet = selectorCount / facetCount;
        uint256 remainder = selectorCount % facetCount;
        uint256 index = NUM_LOUPE_SELECTORS;

        for (uint256 facetIndex; facetIndex < facetCount; facetIndex++) {
            uint256 selectorsForFacet = basePerFacet;
            if (facetIndex < remainder) {
                selectorsForFacet += 1;
            }

            address facet = _facetAddr(facetIndex);
            for (uint16 j; j < selectorsForFacet; j++) {
                bytes4 selector = _selectorFor(facetIndex, j);
                _storeSelectorAtIndex(account, selector, index);
                _storeFacetAndPosition(account, selector, facet, j);
                unchecked {
                    index++;
                }
            }
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

    function _configs() internal pure returns (Configuration[] memory configs) {
        configs = new Configuration[](13);
        configs[0] = Configuration({selectors: 0, facets: 0});
        configs[1] = Configuration({selectors: 2, facets: 1});
        configs[2] = Configuration({selectors: 4, facets: 2});
        configs[3] = Configuration({selectors: 6, facets: 3});
        configs[4] = Configuration({selectors: 40, facets: 10});
        configs[5] = Configuration({selectors: 40, facets: 20});
        configs[6] = Configuration({selectors: 64, facets: 16});
        configs[7] = Configuration({selectors: 64, facets: 32});
        configs[8] = Configuration({selectors: 64, facets: 64});
        configs[9] = Configuration({selectors: 504, facets: 42});
        configs[10] = Configuration({selectors: 1000, facets: 84});
        configs[11] = Configuration({selectors: 10000, facets: 834});
        configs[12] = Configuration({selectors: 40000, facets: 5000});
    }

}
