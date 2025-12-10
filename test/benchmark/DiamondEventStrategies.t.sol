// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import "../../src/diamond/DiamondMod.sol" as DiamondMod;

/* Strategy 1: Diamond using single big DiamondCut event */
contract SingleEventDiamond {
    event DiamondCut(DiamondMod.FacetCut[] _diamondCut);

    constructor(DiamondMod.FacetCut[] memory _facets) payable {
        DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
        uint32 selectorPosition = uint32(s.selectors.length);

        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i].facetAddress;
            bytes4[] memory functionSelectors = _facets[i].functionSelectors;

            if (facet.code.length == 0) {
                revert DiamondMod.NoBytecodeAtAddress(facet, "SingleEventDiamond: Add facet has no code");
            }

            for (uint256 selectorIndex; selectorIndex < functionSelectors.length; selectorIndex++) {
                bytes4 selector = functionSelectors[selectorIndex];
                address oldFacet = s.facetAndPosition[selector].facet;
                if (oldFacet != address(0)) {
                    revert DiamondMod.CannotAddFunctionToDiamondThatAlreadyExists(selector);
                }
                s.facetAndPosition[selector] = DiamondMod.FacetAndPosition(facet, selectorPosition);
                s.selectors.push(selector);
                selectorPosition++;
            }
        }

        emit DiamondCut(_facets);
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}

/* Strategy 2: Diamond using facet-level AddFacet events */
contract FacetEventDiamond {
    event AddFacet(address indexed facetAddress, bytes4[] functionSelectors);

    constructor(DiamondMod.FacetCut[] memory _facets) payable {
        DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
        uint32 selectorPosition = uint32(s.selectors.length);

        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i].facetAddress;
            bytes4[] memory functionSelectors = _facets[i].functionSelectors;

            if (facet.code.length == 0) {
                revert DiamondMod.NoBytecodeAtAddress(facet, "FacetEventDiamond: Add facet has no code");
            }

            for (uint256 selectorIndex; selectorIndex < functionSelectors.length; selectorIndex++) {
                bytes4 selector = functionSelectors[selectorIndex];
                address oldFacet = s.facetAndPosition[selector].facet;
                if (oldFacet != address(0)) {
                    revert DiamondMod.CannotAddFunctionToDiamondThatAlreadyExists(selector);
                }
                s.facetAndPosition[selector] = DiamondMod.FacetAndPosition(facet, selectorPosition);
                s.selectors.push(selector);
                selectorPosition++;
            }

            emit AddFacet(facet, functionSelectors);
        }
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}

/* Strategy 3: Diamond using function-level AddFunction events */
contract FunctionEventDiamond {
    event AddFunction(bytes4 indexed _selector, address indexed _facetAddress);

    constructor(DiamondMod.FacetCut[] memory _facets) payable {
        DiamondMod.DiamondStorage storage s = DiamondMod.getStorage();
        uint32 selectorPosition = uint32(s.selectors.length);

        for (uint256 i; i < _facets.length; i++) {
            address facet = _facets[i].facetAddress;
            bytes4[] memory functionSelectors = _facets[i].functionSelectors;

            if (facet.code.length == 0) {
                revert DiamondMod.NoBytecodeAtAddress(facet, "FunctionEventDiamond: Add facet has no code");
            }

            for (uint256 selectorIndex; selectorIndex < functionSelectors.length; selectorIndex++) {
                bytes4 selector = functionSelectors[selectorIndex];
                address oldFacet = s.facetAndPosition[selector].facet;
                if (oldFacet != address(0)) {
                    revert DiamondMod.CannotAddFunctionToDiamondThatAlreadyExists(selector);
                }
                s.facetAndPosition[selector] = DiamondMod.FacetAndPosition(facet, selectorPosition);
                s.selectors.push(selector);
                selectorPosition++;

                emit AddFunction(selector, facet);
            }
        }
    }

    fallback() external payable {
        DiamondMod.diamondFallback();
    }

    receive() external payable {}
}

/* Mock facet with 8 functions for testing */
contract MockFacet {
    function function01() external pure returns (uint256) {
        return 1;
    }

    function function02() external pure returns (uint256) {
        return 2;
    }

    function function03() external pure returns (uint256) {
        return 3;
    }

    function function04() external pure returns (uint256) {
        return 4;
    }

    function function05() external pure returns (uint256) {
        return 5;
    }

    function function06() external pure returns (uint256) {
        return 6;
    }

    function function07() external pure returns (uint256) {
        return 7;
    }

    function function08() external pure returns (uint256) {
        return 8;
    }
}

/*//////////////////////////////////////////////////////////////
                        TEST CONTRACT
//////////////////////////////////////////////////////////////*/

/**
 * Gas benchmark comparing event strategies for adding functions to diamonds
 * Tests scenarios: 10, 50, and 100 facets with 8 selectors each
 */
contract DiamondEventStrategiesTest is Test {
    uint256 constant SELECTORS_PER_FACET = 8;

    function _deployFacets(uint256 count) internal returns (address[] memory facets) {
        facets = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            facets[i] = address(new MockFacet());
        }
    }

    function _generateSelectorsForFacet(uint256 facetIndex) internal pure returns (bytes4[] memory selectors) {
        selectors = new bytes4[](SELECTORS_PER_FACET);
        for (uint256 i = 0; i < SELECTORS_PER_FACET; i++) {
            selectors[i] = bytes4(keccak256(abi.encodePacked("facet", facetIndex, "func", i)));
        }
    }

    function _buildFacetCuts(address[] memory facets) internal pure returns (DiamondMod.FacetCut[] memory cuts) {
        cuts = new DiamondMod.FacetCut[](facets.length);
        for (uint256 i = 0; i < facets.length; i++) {
            bytes4[] memory selectors = _generateSelectorsForFacet(i);
            cuts[i] = DiamondMod.FacetCut({
                facetAddress: facets[i], action: DiamondMod.FacetCutAction.Add, functionSelectors: selectors
            });
        }
    }

    /*//////////////////////////////////////////////////////////////
                    STRATEGY 1: SINGLE BIG EVENT
    //////////////////////////////////////////////////////////////*/

    function testGas_SingleEvent_010Facets() external {
        address[] memory facets = _deployFacets(10);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        SingleEventDiamond diamond = new SingleEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Single Event (10 facets, 80 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_SingleEvent_050Facets() external {
        address[] memory facets = _deployFacets(50);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        SingleEventDiamond diamond = new SingleEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Single Event (50 facets, 400 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_SingleEvent_100Facets() external {
        address[] memory facets = _deployFacets(100);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        SingleEventDiamond diamond = new SingleEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Single Event (100 facets, 800 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    STRATEGY 2: FACET LEVEL EVENTS
    //////////////////////////////////////////////////////////////*/

    function testGas_FacetEvent_010Facets() external {
        address[] memory facets = _deployFacets(10);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        FacetEventDiamond diamond = new FacetEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Facet Event (10 facets, 80 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_FacetEvent_050Facets() external {
        address[] memory facets = _deployFacets(50);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        FacetEventDiamond diamond = new FacetEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Facet Event (50 facets, 400 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_FacetEvent_100Facets() external {
        address[] memory facets = _deployFacets(100);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        FacetEventDiamond diamond = new FacetEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Facet Event (100 facets, 800 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    /*//////////////////////////////////////////////////////////////
                    STRATEGY 3: FUNCTION LEVEL EVENTS
    //////////////////////////////////////////////////////////////*/

    function testGas_FunctionEvent_010Facets() external {
        address[] memory facets = _deployFacets(10);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        FunctionEventDiamond diamond = new FunctionEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Function Event (10 facets, 80 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_FunctionEvent_050Facets() external {
        address[] memory facets = _deployFacets(50);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        FunctionEventDiamond diamond = new FunctionEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Function Event (50 facets, 400 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }

    function testGas_FunctionEvent_100Facets() external {
        address[] memory facets = _deployFacets(100);
        DiamondMod.FacetCut[] memory cuts = _buildFacetCuts(facets);

        uint256 startGas = gasleft();
        FunctionEventDiamond diamond = new FunctionEventDiamond(cuts);
        uint256 gasUsed = startGas - gasleft();

        emit log_named_uint("Function Event (100 facets, 800 selectors) - Total Gas", gasUsed);

        assertTrue(address(diamond) != address(0));
    }
}
