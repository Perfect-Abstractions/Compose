// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";
import {DiamondUpgrade_Base_Test} from "test/unit/diamond/DiamondUpgradeBase.t.sol";
import {
    FacetA,
    FacetAChanged,
    FacetB,
    FacetBChanged,
    FacetC,
    FacetCChanged
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";
import {DiamondStorageUtils} from "test/utils/storage/DiamondStorageUtils.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
abstract contract ReplaceFacetsBehavior is DiamondUpgrade_Base_Test {
    using DiamondStorageUtils for address;

    bytes32 private constant FACET_REPLACED_TOPIC = keccak256("FacetReplaced(address,address)");

    function _cannotReplaceFacetWithSameFacetError() internal pure virtual returns (bytes4);

    function _facetToReplaceDoesNotExistError() internal pure virtual returns (bytes4);

    function _cannotReplaceFunctionFromNonReplacementFacetError() internal pure virtual returns (bytes4);

    function test_RevertWhen_ReplacingFacetWithSameFacet() external {
        vm.expectRevert(abi.encodeWithSelector(_cannotReplaceFacetWithSameFacetError(), address(facetA)));
        _replace(address(facetA), address(facetA));
    }

    function test_RevertWhen_FacetToReplaceDoesNotExist() external {
        vm.expectRevert(abi.encodeWithSelector(_facetToReplaceDoesNotExistError(), address(facetA)));
        _replace(address(facetA), address(facetAReplacement));
    }

    function test_RevertWhen_NewFirstSelectorBelongsToDifferentFacet() external {
        _seedReplacementABC();

        vm.expectRevert(
            abi.encodeWithSelector(_cannotReplaceFunctionFromNonReplacementFacetError(), FacetB.b1.selector)
        );
        _replace(address(facetA), address(facetBReplacement));
    }

    function test_RevertWhen_NewNonFirstSelectorBelongsToDifferentFacet() external {
        _seedReplacementABC();

        vm.expectRevert(
            abi.encodeWithSelector(_cannotReplaceFunctionFromNonReplacementFacetError(), FacetB.b2.selector)
        );
        _replace(address(facetA), address(facetBChanged));
    }

    function test_ShouldNotChangeState_WhenReplacementArrayIsEmpty() external {
        _seedReplacementABC();

        vm.recordLogs();
        _upgrade(
            _emptyAddresses(), _emptyReplacements(), _emptyAddresses(), address(0), bytes(""), bytes32(0), bytes("")
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0, "empty replacement log count");
        _assertReplacementOriginalABC();
    }

    function test_ShouldReplaceInPlace_WhenSelectorSetsAreIdentical() external {
        _addReplacementFacet(address(facetA));

        _replaceAndAssertSingleEvent(address(facetA), address(facetAReplacement));

        _assertNode(FacetA.a1.selector, address(facetAReplacement), bytes4(0), bytes4(0));
        _assertNode(FacetA.a2.selector, address(facetAReplacement), bytes4(0), bytes4(0));
        _assertNode(FacetA.a3.selector, address(facetAReplacement), bytes4(0), bytes4(0));
        _assertReplacementList(FacetA.a1.selector, FacetA.a1.selector, 1, 3);
    }

    function test_ShouldAddSharedAndRemoveStaleSelectors_WhenSelectorSetsDiffer() external {
        _addReplacementFacet(address(facetA));

        _replaceAndAssertSingleEvent(address(facetA), address(facetAChanged));

        _assertNode(FacetA.a1.selector, address(0), bytes4(0), bytes4(0));
        _assertSelectorOwner(FacetA.a2.selector, address(facetAChanged));
        _assertSelectorOwner(FacetA.a3.selector, address(0));
        _assertSelectorOwner(FacetAChanged.a4.selector, address(facetAChanged));
        _assertSelectorOwner(FacetAChanged.a5.selector, address(facetAChanged));
        _assertNode(FacetAChanged.a4.selector, address(facetAChanged), bytes4(0), bytes4(0));
        _assertNode(FacetA.a2.selector, address(facetAChanged), bytes4(0), bytes4(0));
        _assertNode(FacetAChanged.a5.selector, address(facetAChanged), bytes4(0), bytes4(0));
        _assertCounts(1, 3);
        _assertReplacementList(FacetAChanged.a4.selector, FacetAChanged.a4.selector, 1, 3);
    }

    function test_ShouldRelink_WhenReplacingHeadFacet() external {
        _seedReplacementABC();

        _replaceAndAssertSingleEvent(address(facetA), address(facetAChanged));

        _assertNode(FacetA.a1.selector, address(0), bytes4(0), bytes4(0));
        _assertSelectorOwner(FacetA.a3.selector, address(0));
        _assertNode(FacetAChanged.a4.selector, address(facetAChanged), bytes4(0), FacetB.b1.selector);
        _assertNode(FacetA.a2.selector, address(facetAChanged), bytes4(0), bytes4(0));
        _assertNode(FacetAChanged.a5.selector, address(facetAChanged), bytes4(0), bytes4(0));
        _assertNode(FacetB.b1.selector, address(facetB), FacetAChanged.a4.selector, FacetC.c1.selector);
        _assertNode(FacetC.c1.selector, address(facetC), FacetB.b1.selector, bytes4(0));
        _assertUnchangedBAndCSelectors();
        _assertReplacementList(FacetAChanged.a4.selector, FacetC.c1.selector, 3, 9);
    }

    function test_ShouldRelink_WhenReplacingMiddleFacet() external {
        _seedReplacementABC();

        _replaceAndAssertSingleEvent(address(facetB), address(facetBChanged));

        _assertNode(FacetB.b1.selector, address(0), bytes4(0), bytes4(0));
        _assertSelectorOwner(FacetB.b3.selector, address(0));
        _assertNode(FacetA.a1.selector, address(facetA), bytes4(0), FacetBChanged.b4.selector);
        _assertNode(FacetBChanged.b4.selector, address(facetBChanged), FacetA.a1.selector, FacetC.c1.selector);
        _assertNode(FacetB.b2.selector, address(facetBChanged), bytes4(0), bytes4(0));
        _assertNode(FacetBChanged.b5.selector, address(facetBChanged), bytes4(0), bytes4(0));
        _assertNode(FacetC.c1.selector, address(facetC), FacetBChanged.b4.selector, bytes4(0));
        _assertUnchangedAAndCSelectors();
        _assertReplacementList(FacetA.a1.selector, FacetC.c1.selector, 3, 9);
    }

    function test_ShouldRelink_WhenReplacingTailFacet() external {
        _seedReplacementABC();

        _replaceAndAssertSingleEvent(address(facetC), address(facetCChanged));

        _assertNode(FacetC.c1.selector, address(0), bytes4(0), bytes4(0));
        _assertSelectorOwner(FacetC.c3.selector, address(0));
        _assertNode(FacetA.a1.selector, address(facetA), bytes4(0), FacetB.b1.selector);
        _assertNode(FacetB.b1.selector, address(facetB), FacetA.a1.selector, FacetCChanged.c4.selector);
        _assertNode(FacetCChanged.c4.selector, address(facetCChanged), FacetB.b1.selector, bytes4(0));
        _assertNode(FacetC.c2.selector, address(facetCChanged), bytes4(0), bytes4(0));
        _assertNode(FacetCChanged.c5.selector, address(facetCChanged), bytes4(0), bytes4(0));
        _assertUnchangedAAndBSelectors();
        _assertReplacementList(FacetA.a1.selector, FacetCChanged.c4.selector, 3, 9);
    }

    function _replace(address _oldFacet, address _newFacet) private {
        _upgrade(
            _emptyAddresses(),
            _singleReplacement(_oldFacet, _newFacet),
            _emptyAddresses(),
            address(0),
            bytes(""),
            bytes32(0),
            bytes("")
        );
    }

    function _replaceAndAssertSingleEvent(address _oldFacet, address _newFacet) private {
        vm.recordLogs();
        _replace(_oldFacet, _newFacet);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1, "replacement log count");
        _assertReplacementLog(logs[0], _oldFacet, _newFacet);
    }

    function _addReplacementFacet(address _facet) private {
        _upgrade(
            _singleAddress(_facet),
            _emptyReplacements(),
            _emptyAddresses(),
            address(0),
            bytes(""),
            bytes32(0),
            bytes("")
        );
    }

    function _seedReplacementABC() private {
        _upgrade(
            _threeFacets(address(facetA), address(facetB), address(facetC)),
            _emptyReplacements(),
            _emptyAddresses(),
            address(0),
            bytes(""),
            bytes32(0),
            bytes("")
        );
    }

    function _assertReplacementList(bytes4 _head, bytes4 _tail, uint32 _facetCount, uint32 _selectorCount)
        private
        view
    {
        (bytes4 head, bytes4 tail, uint32 facetCount, uint32 selectorCount) = target.facetList();
        assertEq(head, _head, "head");
        assertEq(tail, _tail, "tail");
        assertEq(facetCount, _facetCount, "facetCount");
        assertEq(selectorCount, _selectorCount, "selectorCount");
    }

    function _assertReplacementLog(Vm.Log memory _log, address _oldFacet, address _newFacet) private view {
        assertEq(_log.emitter, target, "replacement emitter");
        assertEq(_log.topics.length, 3, "replacement topic count");
        assertEq(_log.topics[0], FACET_REPLACED_TOPIC, "replacement topic");
        assertEq(address(uint160(uint256(_log.topics[1]))), _oldFacet, "replacement old facet");
        assertEq(address(uint160(uint256(_log.topics[2]))), _newFacet, "replacement new facet");
        assertEq(_log.data.length, 0, "replacement data length");
    }

    function _assertReplacementOriginalABC() private view {
        _assertNode(FacetA.a1.selector, address(facetA), bytes4(0), FacetB.b1.selector);
        _assertNode(FacetA.a2.selector, address(facetA), bytes4(0), bytes4(0));
        _assertNode(FacetA.a3.selector, address(facetA), bytes4(0), bytes4(0));
        _assertNode(FacetB.b1.selector, address(facetB), FacetA.a1.selector, FacetC.c1.selector);
        _assertNode(FacetB.b2.selector, address(facetB), bytes4(0), bytes4(0));
        _assertNode(FacetB.b3.selector, address(facetB), bytes4(0), bytes4(0));
        _assertNode(FacetC.c1.selector, address(facetC), FacetB.b1.selector, bytes4(0));
        _assertNode(FacetC.c2.selector, address(facetC), bytes4(0), bytes4(0));
        _assertNode(FacetC.c3.selector, address(facetC), bytes4(0), bytes4(0));
        _assertReplacementList(FacetA.a1.selector, FacetC.c1.selector, 3, 9);
    }

    function _assertUnchangedAAndBSelectors() private view {
        _assertSelectorOwner(FacetA.a1.selector, address(facetA));
        _assertSelectorOwner(FacetA.a2.selector, address(facetA));
        _assertSelectorOwner(FacetA.a3.selector, address(facetA));
        _assertSelectorOwner(FacetB.b1.selector, address(facetB));
        _assertSelectorOwner(FacetB.b2.selector, address(facetB));
        _assertSelectorOwner(FacetB.b3.selector, address(facetB));
    }

    function _assertUnchangedAAndCSelectors() private view {
        _assertSelectorOwner(FacetA.a1.selector, address(facetA));
        _assertSelectorOwner(FacetA.a2.selector, address(facetA));
        _assertSelectorOwner(FacetA.a3.selector, address(facetA));
        _assertSelectorOwner(FacetC.c1.selector, address(facetC));
        _assertSelectorOwner(FacetC.c2.selector, address(facetC));
        _assertSelectorOwner(FacetC.c3.selector, address(facetC));
    }

    function _assertUnchangedBAndCSelectors() private view {
        _assertSelectorOwner(FacetB.b1.selector, address(facetB));
        _assertSelectorOwner(FacetB.b2.selector, address(facetB));
        _assertSelectorOwner(FacetB.b3.selector, address(facetB));
        _assertSelectorOwner(FacetC.c1.selector, address(facetC));
        _assertSelectorOwner(FacetC.c2.selector, address(facetC));
        _assertSelectorOwner(FacetC.c3.selector, address(facetC));
    }
}
