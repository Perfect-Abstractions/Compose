// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {DiamondCutFacet} from "../../src/diamond/DiamondCutFacet.sol";
import {DiamondCutFacetHarness} from "./harnesses/DiamondCutFacetHarness.sol";
import {ERC20FacetHarness} from "../token/ERC20/ERC20/harnesses/ERC20FacetHarness.sol";

contract DiamondCutFacetTest is Test {
    DiamondCutFacetHarness public facet;
    ERC20FacetHarness public token;

    address public owner;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1000000e18;
    address constant ADDRESS_ZERO = address(0);

    function setUp() public {
        owner = makeAddr("owner");

        facet = new DiamondCutFacetHarness();
        facet.initialize(owner);

        token = new ERC20FacetHarness();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    // ============================================
    // Helpers
    // ============================================

    function _basicAction()
        internal
        view
        returns (DiamondCutFacet.FacetCut[] memory _cut, address _init, bytes memory _calldata)
    {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        _init = ADDRESS_ZERO;
        _calldata = bytes("0x0");
    }

    modifier addActionSetup() {
        (DiamondCutFacet.FacetCut[] memory _cut, address _init, bytes memory _calldata) = _basicAction();

        vm.prank(owner);
        facet.diamondCut(_cut, _init, _calldata);

        _;
    }

    // ============================================
    // Initialization Test
    // ============================================

    function test_DiamondCut_wrongOwner() public {
        (DiamondCutFacet.FacetCut[] memory _cut, address _init, bytes memory _calldata) = _basicAction();

        vm.expectRevert(DiamondCutFacet.OwnerUnauthorizedAccount.selector);
        facet.diamondCut(_cut, _init, _calldata);
    }

    // ============================================
    // Core Functionality Tests
    // ============================================

    function test_DiamondCut_addAction() public {
        (DiamondCutFacet.FacetCut[] memory _cut, address _init, bytes memory _calldata) = _basicAction();

        vm.recordLogs();

        vm.prank(owner);
        facet.diamondCut(_cut, _init, _calldata);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes memory data = abi.encode(_cut, _init, _calldata);

        assertEq(entries[0].data, data);
    }

    function test_DiamondCut_addActionWhereFunctionAlreadyExists() public addActionSetup {
        (DiamondCutFacet.FacetCut[] memory _cut, address _init, bytes memory _calldata) = _basicAction();

        bytes4 functionSelector = _cut[0].functionSelectors[0];

        vm.prank(owner);

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCutFacet.CannotAddFunctionToDiamondThatAlreadyExists.selector, functionSelector
            )
        );
        // vm.expectRevert();
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_removeAction() public addActionSetup {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: ADDRESS_ZERO,
            action: DiamondCutFacet.FacetCutAction.Remove,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.recordLogs();

        vm.prank(owner);
        facet.diamondCut(_cut, _init, _calldata);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes memory data = abi.encode(_cut, _init, _calldata);

        assertEq(entries[0].data, data);
    }

    function test_DiamondCut_removeActionWithoutZeroAddress() public addActionSetup {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Remove,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(DiamondCutFacet.RemoveFacetAddressMustBeZeroAddress.selector, address(token))
        );
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_removeActionOnFunctionThatDoesNotExist() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: ADDRESS_ZERO,
            action: DiamondCutFacet.FacetCutAction.Remove,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(DiamondCutFacet.CannotRemoveFunctionThatDoesNotExist.selector, functionSelectors[0])
        );
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_replaceAction() public addActionSetup {
        // New ERC20 Facet
        ERC20FacetHarness newFacet = new ERC20FacetHarness();
        newFacet.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(newFacet),
            action: DiamondCutFacet.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.recordLogs();

        vm.prank(owner);
        facet.diamondCut(_cut, _init, _calldata);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes memory data = abi.encode(_cut, _init, _calldata);

        assertEq(entries[0].data, data);
    }

    function test_DiamondCut_replaceActionWithSameFacetAndSameFunction() public addActionSetup {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCutFacet.CannotReplaceFunctionWithTheSameFunctionFromTheSameFacet.selector, functionSelectors[0]
            )
        );
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_replaceActionWithFacetThatDoesNotExists() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCutFacet.CannotReplaceFunctionThatDoesNotExists.selector, functionSelectors[0]
            )
        );
        facet.diamondCut(_cut, _init, _calldata);
    }

    /// This test multiple actions in a single call.
    /// 1. Add the function to a facet.
    /// 2. Replace the function with another facet.
    /// 3. Remove the function.
    function test_DiamondCut_multipleActions() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("balanceOf(address)"));

        // New ERC20 Facet
        ERC20FacetHarness newFacet = new ERC20FacetHarness();
        newFacet.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](3);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        _cut[1] = DiamondCutFacet.FacetCut({
            facetAddress: address(newFacet),
            action: DiamondCutFacet.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        _cut[2] = DiamondCutFacet.FacetCut({
            facetAddress: ADDRESS_ZERO,
            action: DiamondCutFacet.FacetCutAction.Remove,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.recordLogs();

        vm.prank(owner);
        facet.diamondCut(_cut, _init, _calldata);

        Vm.Log[] memory entries = vm.getRecordedLogs();

        bytes memory data = abi.encode(_cut, _init, _calldata);

        assertEq(entries[0].data, data);
    }
}
