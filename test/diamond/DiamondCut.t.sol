// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import "../../src/diamond/DiamondCut.sol" as DiamondCut;
import {DiamondHarness} from "./harnesses/DiamondHarness.sol";
import {ERC20FacetHarness} from "../token/ERC20/ERC20/harnesses/ERC20FacetHarness.sol";
import {ERC20FacetWithFallbackHarness} from "./harnesses/ERC20FacetWithFallbackHarness.sol";

contract LibDiamondHarnessTest is Test {
    DiamondHarness public harness;
    ERC20FacetHarness public facet;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;
    address constant ADDRESS_ZERO = address(0);

    function setUp() public {
        harness = new DiamondHarness();

        facet = new ERC20FacetHarness();
        facet.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    /**
     * ============================================
     * Helpers
     * ============================================
     */

    modifier addFunctionSetup() {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(facet), _functionSelectors);

        _;
    }

    /**
     * ============================================
     * Core Functionality Tests
     * ============================================
     */

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

        DiamondCut.FacetCut[] memory _cut = new DiamondCut.FacetCut[](1);
        _cut[0] = DiamondCut.FacetCut({
            facetAddress: address(facet),
            action: DiamondCut.FacetCutAction.Add,
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

    /**
     * ============================================
     * Error Condition Tests
     * ============================================
     */

    function test_addFunctions_FacetWithZeroCode() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        address facetWithZeroCode = makeAddr("zerocode");

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCut.NoBytecodeAtAddress.selector, facetWithZeroCode, "LibDiamond: Add facet has no code"
            )
        );
        harness.addFunctions(facetWithZeroCode, _functionSelectors);
    }

    function test_addFunctions_FacetThatAlreadyExists() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCut.CannotAddFunctionToDiamondThatAlreadyExists.selector, _functionSelectors[0]
            )
        );
        harness.addFunctions(address(facet), _functionSelectors);
    }

    function test_replaceFunctions_FacetWithZeroCode() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        address facetWithZeroCode = makeAddr("zerocode");

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCut.NoBytecodeAtAddress.selector, facetWithZeroCode, "LibDiamond: Replace facet has no code"
            )
        );
        harness.replaceFunctions(facetWithZeroCode, _functionSelectors);
    }

    function test_replaceFunctions_ReplacingImmutableFunction() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(harness), _functionSelectors);

        vm.expectRevert(
            abi.encodeWithSelector(DiamondCut.CannotReplaceImmutableFunction.selector, _functionSelectors[0])
        );
        harness.replaceFunctions(address(facet), _functionSelectors);
    }

    function test_replaceFunctions_ReplacingWithSameFacet() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCut.CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet.selector, _functionSelectors[0]
            )
        );
        harness.replaceFunctions(address(facet), _functionSelectors);
    }

    function test_replaceFunctions_ReplaceFunctionThatDoesNotExists() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("balanceOf()"));

        ERC20FacetHarness newFacet = new ERC20FacetHarness();

        vm.expectRevert(
            abi.encodeWithSelector(DiamondCut.CannotReplaceFunctionThatDoesNotExists.selector, _functionSelectors[0])
        );
        harness.replaceFunctions(address(newFacet), _functionSelectors);
    }

    function test_removeFunctions_FacetAddressNotZero() public addFunctionSetup {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        vm.expectRevert(
            abi.encodeWithSelector(DiamondCut.RemoveFacetAddressMustBeZeroAddress.selector, address(facet))
        );
        harness.removeFunctions(address(facet), _functionSelectors);
    }

    function test_removeFunctions_RemovingFunctionThatDoesNotExists() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        vm.expectRevert(
            abi.encodeWithSelector(DiamondCut.CannotRemoveFunctionThatDoesNotExist.selector, _functionSelectors[0])
        );
        harness.removeFunctions(ADDRESS_ZERO, _functionSelectors);
    }

    function test_removeFunctions_RemovingImmutableFunction() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        harness.addFunctions(address(harness), _functionSelectors);

        vm.expectRevert(
            abi.encodeWithSelector(DiamondCut.CannotRemoveImmutableFunction.selector, _functionSelectors[0])
        );
        harness.removeFunctions(ADDRESS_ZERO, _functionSelectors);
    }

    function test_diamondCut_InitAddressWithZeroCode() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCut.FacetCut[] memory _cut = new DiamondCut.FacetCut[](1);
        _cut[0] = DiamondCut.FacetCut({
            facetAddress: address(facet),
            action: DiamondCut.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });

        address _init = makeAddr("zerocode");
        bytes memory _calldata = abi.encode("0x00");

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCut.NoBytecodeAtAddress.selector, _init, "LibDiamond: _init address no code"
            )
        );
        harness.diamondCut(_cut, _init, _calldata);
    }

    function test_diamondCut_WithZeroFunctionSelectors() public {
        bytes4[] memory _functionSelectors = new bytes4[](0);

        DiamondCut.FacetCut[] memory _cut = new DiamondCut.FacetCut[](1);
        _cut[0] = DiamondCut.FacetCut({
            facetAddress: address(facet),
            action: DiamondCut.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = abi.encode("0x00");

        vm.expectRevert(abi.encodeWithSelector(DiamondCut.NoSelectorsProvidedForFacet.selector, address(facet)));
        harness.diamondCut(_cut, _init, _calldata);
    }

    function test_diamondCut_InitializeCallWithWrongCalldata() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCut.FacetCut[] memory _cut = new DiamondCut.FacetCut[](1);
        _cut[0] = DiamondCut.FacetCut({
            facetAddress: address(facet),
            action: DiamondCut.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });

        ERC20FacetHarness newFacet = new ERC20FacetHarness();
        address _init = address(newFacet);

        bytes memory _wrongCalldata = abi.encodeWithSelector(bytes4(keccak256("doesNotExist(uint256)")), uint256(123));

        vm.expectRevert(
            abi.encodeWithSelector(DiamondCut.InitializationFunctionReverted.selector, _init, _wrongCalldata)
        );
        harness.diamondCut(_cut, _init, _wrongCalldata);
    }

    function test_diamondCut_InitializeCallWithWrongCalldataReturningErrorMessage() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCut.FacetCut[] memory _cut = new DiamondCut.FacetCut[](1);
        _cut[0] = DiamondCut.FacetCut({
            facetAddress: address(facet),
            action: DiamondCut.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });

        ERC20FacetWithFallbackHarness newFacet = new ERC20FacetWithFallbackHarness();
        address _init = address(newFacet);

        bytes memory _wrongCalldata = abi.encodeWithSelector(bytes4(keccak256("doesNotExist(uint256)")), uint256(123));

        vm.expectRevert(abi.encode("WRONG FUNCTION CALL"));
        harness.diamondCut(_cut, _init, _wrongCalldata);
    }

    /**
     * ============================================
     * Multiple Functions Tests
     * ============================================
     */

    function test_removeFunctions_RemovingFunctionFromMultipleFunctions() public {
        bytes4[] memory _functionSelectors = new bytes4[](2);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));
        _functionSelectors[1] = bytes4(keccak256("balanceOf(address)"));

        harness.addFunctions(address(facet), _functionSelectors);

        (, uint32 positionOfSelectorBeforeRemoval) = harness.getFacetAndPosition(_functionSelectors[1]);

        bytes4[] memory _functionSelectorToRemove = new bytes4[](1);
        _functionSelectorToRemove[0] = bytes4(keccak256("decimals()"));

        harness.removeFunctions(ADDRESS_ZERO, _functionSelectorToRemove);

        (, uint32 positionOfFunctionSelectorAfterRemoval) = harness.getFacetAndPosition(_functionSelectors[1]);

        assertEq(positionOfSelectorBeforeRemoval - positionOfFunctionSelectorAfterRemoval, 1);
    }

    /**
     * This test multiple actions in a single call.
     * 1. Add the function to a facet.
     * 2. Replace the function with another facet.
     * 3. Remove the function.
     */
    function test_diamondCut_MultipleActions() public {
        bytes4[] memory _functionSelectors = new bytes4[](1);
        _functionSelectors[0] = bytes4(keccak256("decimals()"));

        /**
         * New ERC20 Facet
         */
        ERC20FacetHarness newFacet = new ERC20FacetHarness();

        DiamondCut.FacetCut[] memory _cut = new DiamondCut.FacetCut[](3);
        _cut[0] = DiamondCut.FacetCut({
            facetAddress: address(facet),
            action: DiamondCut.FacetCutAction.Add,
            functionSelectors: _functionSelectors
        });

        _cut[1] = DiamondCut.FacetCut({
            facetAddress: address(newFacet),
            action: DiamondCut.FacetCutAction.Replace,
            functionSelectors: _functionSelectors
        });

        _cut[2] = DiamondCut.FacetCut({
            facetAddress: ADDRESS_ZERO,
            action: DiamondCut.FacetCutAction.Remove,
            functionSelectors: _functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        harness.diamondCut(_cut, _init, _calldata);

        (address savedFacet,) = harness.getFacetAndPosition(_functionSelectors[0]);
        assertEq(savedFacet, ADDRESS_ZERO);
    }
}
