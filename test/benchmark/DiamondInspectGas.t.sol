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
            s.facetAndPosition[selector] = FacetAndPosition({
                facet: facet,
                position: uint32(i)
            });
        }
    }

    // Generic benchmark function
    function _runBenchmark(uint256 count) internal {
        _populateSelectors(count);

        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamondInspect)
            .delegatecall(
                abi.encodeWithSelector(
                    DiamondInspectFacet.functionFacetPairs.selector
                )
            );
        uint256 gasUsed = startGas - gasleft();

        require(success, "Delegatecall failed");
        DiamondInspectFacet.FunctionFacetPair[] memory pairs = abi.decode(
            data,
            (DiamondInspectFacet.FunctionFacetPair[])
        );

        console.log("Count:", count);
        console.log("Gas Used:", gasUsed);

        assertEq(pairs.length, count);
    }

    // We will call these individually or parameterized to find the limits
    // Sorted by selector count to be visually pleasing and easier to read

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

    function testBenchmark_006000() public {
        _runBenchmark(6000);
    }

    function testBenchmark_010000() public {
        _runBenchmark(10000);
    }

    function testBenchmark_015200() public {
        _runBenchmark(15200);
    }

    function testBenchmark_020000() public {
        _runBenchmark(20000);
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

    function testBenchmark_045000() public {
        _runBenchmark(45000);
    }

    function testBenchmark_050000() public {
        _runBenchmark(50000);
    }

    function testBenchmark_052000() public {
        _runBenchmark(52000);
    }

    function testBenchmark_060000() public {
        _runBenchmark(60000);
    }
}
