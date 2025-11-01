// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibDiamond} from "../../src/diamond/LibDiamond.sol";
import {LibDiamondHarness} from "./harnesses/LibDiamondHarness.sol";
import {ERC20FacetHarness} from "../token/ERC20/ERC20/harnesses/ERC20FacetHarness.sol";

contract LibDiamondHarnessTest is Test {
    LibDiamondHarness public harness;
    ERC20FacetHarness public facet;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;
    address constant ADDRESS_ZERO = address(0);

    function setUp() public {
        harness = new LibDiamondHarness();

        facet = new ERC20FacetHarness();
        facet.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    // ============================================
    // Helpers
    // ============================================

    modifier addFunctionSetup() {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(facet), _functionSelectors);

        _;
    }

    // ============================================
    // Core Functionality Tests
    // ============================================

    function test_addFunctions() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(facet), _functionSelectors);

        (address _savedFacet,) = harness.getFacetAndPosition(_functionSelectors[0]);
        assertEq(_savedFacet, address(facet));
    }

    function test_replaceFunctions() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        ERC20FacetHarness newFacet = new ERC20FacetHarness();

        (address _beforeFacet,) = harness.getFacetAndPosition(_functionSelectors[0]);
        assertEq(_beforeFacet, address(facet));

        harness.replaceFunctions(address(newFacet), _functionSelectors);

        (address _savedFacet,) = harness.getFacetAndPosition(_functionSelectors[0]);
        assertEq(_savedFacet, address(newFacet));
    }

    function test_removeFunctions() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        harness.removeFunctions(ADDRESS_ZERO, _functionSelectors);

        (address _savedFacet,) = harness.getFacetAndPosition(_functionSelectors[0]);
        assertEq(_savedFacet, ADDRESS_ZERO);
    }

    function test_diamondCut() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        LibDiamond.FacetCut[] memory _cut = new LibDiamond.FacetCut[](1);
        _cut[0] = LibDiamond.FacetCut({
            facetAddress: address(facet),
            action: LibDiamond.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });
        address _init = ADDRESS_ZERO;
        bytes memory _calldata = abi.encode("0x00");

        harness.diamondCut(_cut, _init, _calldata);

        (address _savedFacetAddress,) = harness.getFacetAndPosition(_functionSelectors[0]);

        assertEq(_savedFacetAddress, address(facet));
    }

    function test_getSelectors() public {
        bytes4[] memory _functionSelectors = new bytes4[](2);
        _functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));
        _functionSelectors[1] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(facet), _functionSelectors);

        bytes4[] memory saveSelectors = harness.getSelectors();

        if (saveSelectors.length == _functionSelectors.length) {
            uint256 i = 0;
            for (i; i < saveSelectors.length; i++) {
                assertEq(saveSelectors[i], _functionSelectors[i]);
            }
        }
    }

    function test_getSelectorsLength() public {
        bytes4[] memory _functionSelectors = new bytes4[](2);
        _functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));
        _functionSelectors[1] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(facet), _functionSelectors);

        bytes4[] memory saveSelectors = harness.getSelectors();

        assertEq(saveSelectors.length, _functionSelectors.length);
    }
}
