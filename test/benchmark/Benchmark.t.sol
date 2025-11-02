// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {MinimalDiamond} from "./MinimalDiamond.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {DiamondLoupeFacet} from "../../src/diamond/DiamondLoupeFacet.sol";

contract LoupeGasBenchmarkTest is Test {
    MinimalDiamond internal diamond;
    DiamondLoupeFacet internal loupe;

    bytes32 internal constant DIAMOND_STORAGE_POSITION = keccak256("compose.diamond");
    uint256 internal constant NUM_FACETS = 200;
    uint256 internal constant SELECTORS_PER_FACET = 10;
    uint256 internal constant NUM_LOUPE_SELECTORS = 4;
    uint256 internal constant TOTAL_SELECTORS = NUM_FACETS * SELECTORS_PER_FACET + NUM_LOUPE_SELECTORS;

    function setUp() public {
        loupe = new DiamondLoupeFacet();
        diamond = new MinimalDiamond();

        bytes4[] memory loupeSelectors = new bytes4[](NUM_LOUPE_SELECTORS);
        loupeSelectors[0] = DiamondLoupeFacet.facets.selector;
        loupeSelectors[1] = DiamondLoupeFacet.facetFunctionSelectors.selector;
        loupeSelectors[2] = DiamondLoupeFacet.facetAddresses.selector;
        loupeSelectors[3] = DiamondLoupeFacet.facetAddress.selector;

        LibDiamond.FacetCut[] memory dc = new LibDiamond.FacetCut[](1);

        dc[0] = LibDiamond.FacetCut({
            facetAddress: address(loupe),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        MinimalDiamond.DiamondArgs memory args = MinimalDiamond.DiamondArgs({init: address(0), initCalldata: ""});

        diamond.initialize(dc, args);

        _buildDiamond(address(diamond), NUM_FACETS, SELECTORS_PER_FACET);
    }

    /*//////////////////////////////////////////////////////////////
                             GAS BENCHMARKS
    //////////////////////////////////////////////////////////////*/

    // Estimated gas: 370_049_638
    function testGas_Loupe_Facets() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeCall(DiamondLoupeFacet.facets, ()));
        emit log_uint(startGas - gasleft());

        DiamondLoupeFacet.Facet[] memory allFacets = abi.decode(data, (DiamondLoupeFacet.Facet[]));
        assertEq(allFacets.length, NUM_FACETS + 1); // plus Loupe
    }

    // Estimated gas: 5_889_482
    function testGas_Loupe_FacetFunctionSelectors() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) =
            address(diamond).call(abi.encodeCall(DiamondLoupeFacet.facetFunctionSelectors, (address(loupe))));
        emit log_uint(startGas - gasleft());

        bytes4[] memory facetSelectors = abi.decode(data, (bytes4[]));
        assertEq(facetSelectors.length, NUM_LOUPE_SELECTORS);
    }

    // Estimated gas: 31_606_629
    function testGas_Loupe_FacetAddresses() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(abi.encodeCall(DiamondLoupeFacet.facetAddresses, ()));
        emit log_uint(startGas - gasleft());

        address[] memory allFacets = abi.decode(data, (address[]));
        assertEq(allFacets.length, NUM_FACETS + 1); // plus Loupe
    }

    // Estimated gas: 12_654
    function testGas_Loupe_FacetAddress() external {
        uint256 startGas = gasleft();
        (bool success, bytes memory data) = address(diamond).call(
            abi.encodeCall(DiamondLoupeFacet.facetAddress, (DiamondLoupeFacet.facetAddresses.selector))
        );
        emit log_uint(startGas - gasleft());
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

    /*//////////////////////////////////////////////////////////////
                              DATA HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildDiamond(address account, uint256 nFacets, uint256 perFacet) internal {
        uint256 total = nFacets * perFacet;
        vm.store(account, _selectorsLengthSlot(), bytes32(total));

        uint256 globalIndex = 4;
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
        return makeAddr(string.concat("facet ", vm.toString(f)));
    }

    function _selectorFor(uint256 f, uint16 j) internal pure returns (bytes4) {
        return bytes4(keccak256(abi.encodePacked("fn_f_", vm.toString(f), "_idx_", vm.toString(j), "()")));
    }
}
