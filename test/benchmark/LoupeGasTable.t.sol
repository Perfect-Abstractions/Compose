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

    function testTable00_Header() external {
        emit log_string("| selectors/facets | baseline facets() | sharded facets() | baseline facetAddresses() | sharded facetAddresses() |");
        emit log_string("| --- | ---: | ---: | ---: | ---: |");
    }

    function testTable01_Row_0_0() external {
        _runRow(0, 0, false);
    }

    function testTable02_Row_2_1() external {
        _runRow(2, 1, false);
    }

    function testTable03_Row_4_2() external {
        _runRow(4, 2, false);
    }

    function testTable04_Row_6_3() external {
        _runRow(6, 3, false);
    }

    function testTable05_Row_20_7() external {
        _runRow(20, 7, false);
    }

    function testTable06_Row_40_10() external {
        _runRow(40, 10, false);
    }

    function testTable07_Row_40_20() external {
        _runRow(40, 20, false);
    }

    function testTable08_Row_50_17() external {
        _runRow(50, 17, false);
    }

    function testTable09_Row_64_16() external {
        _runRow(64, 16, false);
    }

    function testTable10_Row_64_32() external {
        _runRow(64, 32, false);
    }

    function testTable11_Row_64_64() external {
        _runRow(64, 64, false);
    }

    function testTable12_Row_100_34() external {
        _runRow(100, 34, false);
    }

    function testTable13_Row_500_167() external {
        _runRow(500, 167, false);
    }

    function testTable14_Row_504_42() external {
        _runRow(504, 42, false);
    }

    function testTable15_Row_1000_84() external {
        _runRow(1000, 84, false);
    }

    function testTable16_Row_1000_334() external {
        _runRow(1000, 334, false);
    }

    function testTable17_Row_10000_834() external {
        _runRow(10000, 834, false);
    }

    function testTable18_Row_40000_5000() external {
        _runRow(40000, 5000, false);
    }

    function testPrintCustomRow() external {
        if (!vm.envOr("LOUPE_ROW_ENABLED", false)) {
            return;
        }

        uint256 selectors = vm.envOr("LOUPE_ROW_SELECTORS", uint256(0));
        uint256 facets = vm.envOr("LOUPE_ROW_FACETS", uint256(0));
        bool allowFailure = vm.envOr("LOUPE_ROW_ALLOW_FAILURE", false);

        _runRow(selectors, facets, allowFailure);
    }

    function _runRow(uint256 selectorCount, uint256 facetCount, bool allowFailure) internal {
        bool rowOk = _logRow(selectorCount, facetCount);
        require(allowFailure || rowOk, "configuration failed; see logs");
    }

    function _logRow(uint256 selectorCount, uint256 facetCount) internal returns (bool ok) {
        string memory label = string.concat(vm.toString(selectorCount), "/", vm.toString(facetCount));

        (GasMetrics memory baseline, bool baselineOk, string memory baselineErr) =
            _tryMeasure(false, selectorCount, facetCount, label);
        (GasMetrics memory sharded, bool shardedOk, string memory shardedErr) =
            _tryMeasure(true, selectorCount, facetCount, label);

        string memory baselineFacets = baselineOk ? vm.toString(baseline.facets) : baselineErr;
        string memory shardedFacets = shardedOk ? vm.toString(sharded.facets) : shardedErr;
        string memory baselineAddresses = baselineOk ? vm.toString(baseline.facetAddresses) : baselineErr;
        string memory shardedAddresses = shardedOk ? vm.toString(sharded.facetAddresses) : shardedErr;

        emit log_string(
            string.concat(
                "| ",
                label,
                " | ",
                baselineFacets,
                " | ",
                shardedFacets,
                " | ",
                baselineAddresses,
                " | ",
                shardedAddresses,
                " |"
            )
        );

        ok = baselineOk && shardedOk;
    }

    function _tryMeasure(bool useSharded, uint256 selectorCount, uint256 facetCount, string memory label)
        internal
        returns (GasMetrics memory metrics, bool ok, string memory err)
    {
        try this.measureImplementation(useSharded, selectorCount, facetCount) returns (GasMetrics memory result) {
            return (result, true, "");
        } catch Error(string memory reason) {
            err = bytes(reason).length == 0 ? "error" : reason;
        } catch (bytes memory) {
            err = "OOG";
        }

        metrics = GasMetrics({facets: 0, facetAddresses: 0});
        ok = false;
        emit log_string(string.concat("[warn] ", useSharded ? "sharded" : "baseline", " ", label, " failed: ", err));
    }

    function measureImplementation(bool useSharded, uint256 selectorCount, uint256 facetCount)
        external
        returns (GasMetrics memory metrics)
    {
        require(msg.sender == address(this), "internal use only");
        return _measureUnsafe(useSharded, selectorCount, facetCount);
    }

    function _measureUnsafe(bool useSharded, uint256 selectorCount, uint256 facetCount)
        internal
        returns (GasMetrics memory metrics)
    {
        MinimalDiamond benchDiamond = _deployLoupe(useSharded);

        _populateSelectors(address(benchDiamond), selectorCount, facetCount);

        if (useSharded) {
            _enableShardedLoupe(benchDiamond);
        }

        string memory label = string.concat(vm.toString(selectorCount), "/", vm.toString(facetCount));
        string memory mode = useSharded ? "sharded" : "baseline";

        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(benchDiamond).call(abi.encodeWithSelector(SELECTOR_FACETS));
        uint256 gasUsed = startGas - gasleft();
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
        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
        loupeSelectors[0] = SELECTOR_FACETS;
        loupeSelectors[1] = SELECTOR_FACET_FUNCTION_SELECTORS;
        loupeSelectors[2] = SELECTOR_FACET_ADDRESSES;
        loupeSelectors[3] = SELECTOR_FACET_ADDRESS;

        cuts[0] = LibDiamond.FacetCut({
            facetAddress: loupeAddr,
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
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
}
