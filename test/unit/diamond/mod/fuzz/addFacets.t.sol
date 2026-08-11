// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";

import "src/diamond/DiamondMod.sol" as DiamondMod;
import {DiamondMod_Base_Test} from "test/unit/diamond/DiamondModBase.t.sol";
import {
    DuplicateSelectorFacet,
    FacetA,
    FacetB,
    FacetC,
    SelectorConflictFacet
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract AddFacets_DiamondMod_Fuzz_Unit_Test is DiamondMod_Base_Test {
    bytes32 private constant FACET_ADDED_TOPIC = keccak256("FacetAdded(address)");

    function test_ShouldLeaveFacetListUnchanged_WhenFacetArrayIsEmpty() external {
        harness.addFacets(_singleAddress(address(facetA)));
        vm.recordLogs();

        harness.addFacets(_emptyAddresses());

        Vm.Log[] memory logs = vm.getRecordedLogs();
        _assertFacetList(address(harness), FacetA.a1.selector, FacetA.a1.selector, 1, 3);
        _assertNode(address(harness), FacetA.a1.selector, address(facetA), bytes4(0), bytes4(0));
        assertEq(logs.length, 0, "unexpected logs");
    }

    function test_ShouldRegisterFirstFacetSelectorsAndList() external {
        harness.addFacets(_singleAddress(address(facetA)));

        _assertFacetList(address(harness), FacetA.a1.selector, FacetA.a1.selector, 1, 3);
        _assertNode(address(harness), FacetA.a1.selector, address(facetA), bytes4(0), bytes4(0));
        _assertNode(address(harness), FacetA.a2.selector, address(facetA), bytes4(0), bytes4(0));
        _assertNode(address(harness), FacetA.a3.selector, address(facetA), bytes4(0), bytes4(0));
    }

    function test_ShouldEmitFacetAddedExactlyOnce_WhenAddingFirstFacet() external {
        vm.recordLogs();

        harness.addFacets(_singleAddress(address(facetA)));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "log count");
        _assertFacetAddedLog(logs[0], address(facetA));
    }

    function test_ShouldLinkMultipleFacetsInInputOrder() external {
        address[] memory facets = new address[](3);
        facets[0] = address(facetA);
        facets[1] = address(facetB);
        facets[2] = address(facetC);

        harness.addFacets(facets);

        _assertFacetList(address(harness), FacetA.a1.selector, FacetC.c1.selector, 3, 9);
        _assertNode(address(harness), FacetA.a1.selector, address(facetA), bytes4(0), FacetB.b1.selector);
        _assertNode(address(harness), FacetB.b1.selector, address(facetB), FacetA.a1.selector, FacetC.c1.selector);
        _assertNode(address(harness), FacetC.c1.selector, address(facetC), FacetB.b1.selector, bytes4(0));
        _assertNode(address(harness), FacetB.b2.selector, address(facetB), bytes4(0), bytes4(0));
    }

    function test_ShouldEmitOneFacetAddedPerFacetInInputOrder() external {
        vm.recordLogs();

        harness.addFacets(_threeFacets(address(facetA), address(facetB), address(facetC)));

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 3, "log count");
        _assertFacetAddedLog(logs[0], address(facetA));
        _assertFacetAddedLog(logs[1], address(facetB));
        _assertFacetAddedLog(logs[2], address(facetC));
    }

    function test_ShouldConnectPreviousTailToAppendedFacets() external {
        harness.addFacets(_singleAddress(address(facetA)));

        address[] memory appendedFacets = new address[](2);
        appendedFacets[0] = address(facetB);
        appendedFacets[1] = address(facetC);
        harness.addFacets(appendedFacets);

        _assertFacetList(address(harness), FacetA.a1.selector, FacetC.c1.selector, 3, 9);
        _assertNode(address(harness), FacetA.a1.selector, address(facetA), bytes4(0), FacetB.b1.selector);
        _assertNode(address(harness), FacetB.b1.selector, address(facetB), FacetA.a1.selector, FacetC.c1.selector);
        _assertNode(address(harness), FacetC.c1.selector, address(facetC), FacetB.b1.selector, bytes4(0));
    }

    function test_RevertWhen_SelectorBelongsToAnotherFacet() external {
        SelectorConflictFacet conflictFacet = new SelectorConflictFacet();
        harness.addFacets(_singleAddress(address(facetB)));

        vm.expectRevert(
            abi.encodeWithSelector(DiamondMod.CannotAddFunctionToDiamondThatAlreadyExists.selector, FacetB.b2.selector)
        );
        harness.addFacets(_singleAddress(address(conflictFacet)));
    }

    function test_RevertWhen_FacetExportsDuplicateSelector() external {
        DuplicateSelectorFacet duplicateFacet = new DuplicateSelectorFacet();

        vm.expectRevert(
            abi.encodeWithSelector(
                DiamondMod.CannotAddFunctionToDiamondThatAlreadyExists.selector,
                DuplicateSelectorFacet.duplicate.selector
            )
        );
        harness.addFacets(_singleAddress(address(duplicateFacet)));
    }

    function _assertFacetAddedLog(Vm.Log memory _log, address _facet) private view {
        assertEq(_log.emitter, address(harness), "log emitter");
        assertEq(_log.topics.length, 2, "topic count");
        assertEq(_log.topics[0], FACET_ADDED_TOPIC, "event signature");
        assertEq(_log.topics[1], bytes32(uint256(uint160(_facet))), "facet topic");
        assertEq(_log.data.length, 0, "event data");
    }
}
