// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/diamond/DiamondInspectFacet.sol";

contract DiamondInspectGasTest is Test {
    DiamondInspectFacet diamondInspect;

    bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");

    struct FacetAndPosition {
        address facet;
        uint32 position;
    }

    struct DiamondStorage {
        mapping(bytes4 functionSelector => FacetAndPosition) facetAndPosition;
        bytes4[] selectors;
    }

    function setUp() public {
        diamondInspect = new DiamondInspectFacet();
    }

    // Helper to populate storage directly
    function _populateSelectors(uint256 count) internal {
        bytes32 position = DIAMOND_STORAGE_POSITION;
        DiamondStorage storage s;
        assembly {
            s.slot := position
        }

        // Dummy address
        address facet = address(0x1234567890123456789012345678901234567890);

        for (uint256 i = 0; i < count; i++) {
            // Generate pseudo-random selector
            bytes4 selector = bytes4(keccak256(abi.encode(i)));

            s.selectors.push(selector);
            s.facetAndPosition[selector] = FacetAndPosition({facet: facet, position: uint32(i)});
        }
    }

    // Generic benchmark function
    function _runBenchmark(uint256 count) internal {
        _populateSelectors(count);

        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamondInspect)
            .delegatecall(abi.encodeWithSelector(DiamondInspectFacet.functionFacetPairs.selector));
        uint256 gasUsed = startGas - gasleft();

        require(success, "Delegatecall failed");
        DiamondInspectFacet.FunctionFacetPair[] memory pairs =
            abi.decode(data, (DiamondInspectFacet.FunctionFacetPair[]));

        console.log("Count:", count);
        console.log("Gas Used:", gasUsed);

        assertEq(pairs.length, count);
    }

    function testBenchmark_000100() public {
        _runBenchmark(100);
    }

    function testBenchmark_001000() public {
        _runBenchmark(1000);
    }

    function testBenchmark_005000() public {
        _runBenchmark(5000);
    }

    function testBenchmark_005600() public {
        _runBenchmark(5600);
    }

    //10 mil gas
    function testBenchmark_005665() public {
        _runBenchmark(5665);
    }

    function testBenchmark_006000() public {
        _runBenchmark(6000);
    }

    function testBenchmark_010000() public {
        _runBenchmark(10000);
    }

    function testBenchmark_015200() public {
        _runBenchmark(15200);
    }

    //50 mil gas
    function testBenchmark_015902() public {
        _runBenchmark(15902);
    }

    function testBenchmark_020000() public {
        _runBenchmark(20000);
    }

    //100 mil gas
    function testBenchmark_022000() public {
        _runBenchmark(23778);
    }

    function testBenchmark_024300() public {
        _runBenchmark(24300);
    }

    function testBenchmark_035000() public {
        _runBenchmark(35000);
    }

    function testBenchmark_040000() public {
        _runBenchmark(40000);
    }

    //300 mil gas
    function testBenchmark_044000() public {
        _runBenchmark(43612);
    }

    function testBenchmark_045000() public {
        _runBenchmark(45000);
    }

    function testBenchmark_050000() public {
        _runBenchmark(50000);
    }

    function testBenchmark_052000() public {
        _runBenchmark(52000);
    }

    // 500 mil gas
    function testBenchmark_057315() public {
        _runBenchmark(57315);
    }

    function testBenchmark_060000() public {
        _runBenchmark(60000);
    }
}
