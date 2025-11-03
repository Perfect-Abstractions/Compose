// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {DiamondCutFacetHarness, DiamondCutFacet} from "./harnesses/DiamondCutFacetHarness.sol";
import {ERC20FacetHarness} from "../token/ERC20/ERC20/harnesses/ERC20FacetHarness.sol";
import {ERC20FacetWithFallbackHarness} from "./harnesses/ERC20FacetWithFallbackHarness.sol";

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
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    function test_DiamondCut_removeAction() public addActionSetup {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    function test_DiamondCut_removeActionWithMultipleSelectors() public addActionSetup {
        bytes4[] memory functionSelectorsToAdd = new bytes4[](1);
        bytes4[] memory functionSelectorsToRemove = new bytes4[](1);
        functionSelectorsToAdd[0] = bytes4(keccak256("balanceOf(address)"));
        functionSelectorsToRemove[0] = bytes4(keccak256("decimals()"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](2);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectorsToAdd
        });
        _cut[1] = DiamondCutFacet.FacetCut({
            facetAddress: ADDRESS_ZERO,
            action: DiamondCutFacet.FacetCutAction.Remove,
            functionSelectors: functionSelectorsToRemove
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

    function test_DiamondCut_replaceAction() public addActionSetup {
        // New ERC20 Facet
        ERC20FacetHarness newFacet = new ERC20FacetHarness();
        newFacet.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);

        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    /// This test multiple actions in a single call.
    /// 1. Add the function to a facet.
    /// 2. Replace the function with another facet.
    /// 3. Remove the function.
    function test_DiamondCut_multipleActions() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    function test_DiamondCut_initializeCall() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

        ERC20FacetHarness newFacet = new ERC20FacetHarness();

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(newFacet),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        address _init = address(newFacet);
        bytes memory _calldata =
            abi.encodeWithSelector(newFacet.initialize.selector, TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);

        vm.prank(owner);
        facet.diamondCut(_cut, _init, _calldata);

        assertEq(ERC20FacetHarness(address(facet)).decimals(), TOKEN_DECIMALS);
    }

    // ============================================
    // Error Condition Tests
    // ============================================

    function test_DiamondCut_wrongOwner() public {
        (DiamondCutFacet.FacetCut[] memory _cut, address _init, bytes memory _calldata) = _basicAction();

        vm.expectRevert(DiamondCutFacet.OwnerUnauthorizedAccount.selector);
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_emptySelectorArray() public {
        (, address _init, bytes memory _calldata) = _basicAction();

        bytes4[] memory functionSelectors = new bytes4[](0);

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(DiamondCutFacet.NoSelectorsProvidedForFacet.selector, address(token)));
        facet.diamondCut(_cut, _init, _calldata);
    }

    // function test_DiamondCut_incorrectFacetCutAction() public {
    //     (, address _init, bytes memory _calldata) = _basicAction();

    //     bytes4[] memory functionSelectors = new bytes4[](0);

    //     DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
    //     _cut[0] = DiamondCutFacet.FacetCut({
    //         facetAddress: address(token),
    //         action: DiamondCutFacet.FacetCutAction(uint8(5)),
    //         functionSelectors: functionSelectors
    //     });

    //     vm.prank(owner);
    //     vm.expectRevert(abi.encodeWithSelector(DiamondCutFacet.IncorrectFacetCutAction.selector, 5));
    //     facet.diamondCut(_cut, _init, _calldata);
    // }

    function test_DiamondCut_addActionWithZeroFacetCode() public {
        (, address _init, bytes memory _calldata) = _basicAction();

        address addressWithZeroCode = address(1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: addressWithZeroCode,
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCutFacet.NoBytecodeAtAddress.selector,
                addressWithZeroCode,
                "DiamondCutFacet: Add facet has no code"
            )
        );
        facet.diamondCut(_cut, _init, _calldata);
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

    function test_DiamondCut_removeActionWithoutZeroAddress() public addActionSetup {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    function test_DiamondCut_removeActionRemovingImmutableFunction() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCutFacet.FacetCut[] memory _cutToAddImmutableFunction = new DiamondCutFacet.FacetCut[](1);
        _cutToAddImmutableFunction[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(facet),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.prank(owner);
        facet.diamondCut(_cutToAddImmutableFunction, _init, _calldata);

        DiamondCutFacet.FacetCut[] memory _cutToRemoveImmutableFunction = new DiamondCutFacet.FacetCut[](1);
        _cutToRemoveImmutableFunction[0] = DiamondCutFacet.FacetCut({
            facetAddress: ADDRESS_ZERO,
            action: DiamondCutFacet.FacetCutAction.Remove,
            functionSelectors: functionSelectors
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(DiamondCutFacet.CannotRemoveImmutableFunction.selector, functionSelectors[0])
        );
        facet.diamondCut(_cutToRemoveImmutableFunction, _init, _calldata);
    }

    function test_DiamondCut_replaceActionWithSameFacetAndSameFunction() public addActionSetup {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    function test_DiamondCut_replaceActionWithZeroFacetCode() public addActionSetup {
        (, address _init, bytes memory _calldata) = _basicAction();

        address addressWithZeroCode = address(1);
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCutFacet.FacetCut[] memory _cut = new DiamondCutFacet.FacetCut[](1);
        _cut[0] = DiamondCutFacet.FacetCut({
            facetAddress: addressWithZeroCode,
            action: DiamondCutFacet.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCutFacet.NoBytecodeAtAddress.selector,
                addressWithZeroCode,
                "DiamondCutFacet: Replace facet has no code"
            )
        );
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_replaceActionWithFacetThatDoesNotExists() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

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

    function test_DiamondCut_replaceActionReplacingImmutableFunction() public {
        bytes4[] memory functionSelectors = new bytes4[](1);
        functionSelectors[0] = bytes4(keccak256("decimals()"));

        DiamondCutFacet.FacetCut[] memory _cutToAddImmutableFunction = new DiamondCutFacet.FacetCut[](1);
        _cutToAddImmutableFunction[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(facet),
            action: DiamondCutFacet.FacetCutAction.Add,
            functionSelectors: functionSelectors
        });

        address _init = ADDRESS_ZERO;
        bytes memory _calldata = bytes("0x0");

        vm.prank(owner);
        facet.diamondCut(_cutToAddImmutableFunction, _init, _calldata);

        DiamondCutFacet.FacetCut[] memory _cutToReplaceImmutableFunction = new DiamondCutFacet.FacetCut[](1);
        _cutToReplaceImmutableFunction[0] = DiamondCutFacet.FacetCut({
            facetAddress: address(token),
            action: DiamondCutFacet.FacetCutAction.Replace,
            functionSelectors: functionSelectors
        });

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(DiamondCutFacet.CannotReplaceImmutableFunction.selector, functionSelectors[0])
        );
        facet.diamondCut(_cutToReplaceImmutableFunction, _init, _calldata);
    }

    function test_DiamondCut_initalizeFunctionExecutionWithoutCode() public {
        (DiamondCutFacet.FacetCut[] memory _cut,, bytes memory _calldata) = _basicAction();

        address _init = address(1);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondCutFacet.NoBytecodeAtAddress.selector, _init, "DiamondCutFacet: _init address no code"
            )
        );
        facet.diamondCut(_cut, _init, _calldata);
    }

    function test_DiamondCut_initializeCallWithWrongCalldata() public {
        (DiamondCutFacet.FacetCut[] memory _cut,,) = _basicAction();

        ERC20FacetHarness newFacet = new ERC20FacetHarness();
        address _init = address(newFacet);

        bytes memory _wrongCalldata = abi.encodeWithSelector(bytes4(keccak256("doesNotExist(uint256)")), uint256(123));

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(DiamondCutFacet.InitializationFunctionReverted.selector, _init, _wrongCalldata)
        );
        facet.diamondCut(_cut, _init, _wrongCalldata);
    }

    function test_DiamondCut_initalizeCallWithWrongCalldataReturningErrorMessage() public {
        (DiamondCutFacet.FacetCut[] memory _cut,,) = _basicAction();

        ERC20FacetWithFallbackHarness newFacet = new ERC20FacetWithFallbackHarness();
        address _init = address(newFacet);

        bytes memory _wrongCalldata = abi.encodeWithSelector(
            bytes4(keccak256("initialize(string,string,uint256)")), TOKEN_NAME, TOKEN_DECIMALS, TOKEN_DECIMALS
        );

        vm.prank(owner);
        vm.expectRevert(abi.encode("WRONG FUNCTION CALL"));
        facet.diamondCut(_cut, _init, _wrongCalldata);
    }
}
