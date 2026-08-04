// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Vm} from "forge-std/Vm.sol";
import {DiamondUpgrade_Base_Test} from "test/unit/diamond/DiamondUpgradeBase.t.sol";
import {FacetA, FacetB, FacetC} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";
import {DiamondStorageUtils} from "test/utils/storage/DiamondStorageUtils.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
abstract contract RemoveFacetsBehavior is DiamondUpgrade_Base_Test {
    using DiamondStorageUtils for address;

    bytes32 private constant FACET_REMOVED_TOPIC = keccak256("FacetRemoved(address)");

    function _cannotRemoveFacetThatDoesNotExistError() internal pure virtual returns (bytes4);

    function test_ShouldNotChangeState_WhenRemoveArrayIsEmpty() external {
        _remove(_emptyAddresses());

        _assertRemovalList(bytes4(0), bytes4(0), 0, 0);
    }

    function test_RevertWhen_RemovingFacetThatDoesNotExist() external {
        _addRemovalFacet(address(facetA));

        vm.expectRevert(abi.encodeWithSelector(_cannotRemoveFacetThatDoesNotExistError(), address(facetAReplacement)));
        _remove(_singleAddress(address(facetAReplacement)));

        _assertOnlyFacetA();
    }

    function test_ShouldClearList_WhenRemovingOnlyFacet() external {
        _addRemovalFacet(address(facetA));

        _remove(_singleAddress(address(facetA)));

        _assertFacetACleared();
        _assertRemovalList(bytes4(0), bytes4(0), 0, 0);
    }

    function test_ShouldRelink_WhenRemovingHeadFacet() external {
        _seedRemovalABC();

        _remove(_singleAddress(address(facetA)));

        _assertFacetACleared();
        _assertNode(FacetB.b1.selector, address(facetB), bytes4(0), FacetC.c1.selector);
        _assertNode(FacetC.c1.selector, address(facetC), FacetB.b1.selector, bytes4(0));
        _assertFacetBSelectors();
        _assertFacetCSelectors();
        _assertRemovalList(FacetB.b1.selector, FacetC.c1.selector, 2, 6);
    }

    function test_ShouldRelink_WhenRemovingMiddleFacet() external {
        _seedRemovalABC();

        _remove(_singleAddress(address(facetB)));

        _assertFacetBCleared();
        _assertNode(FacetA.a1.selector, address(facetA), bytes4(0), FacetC.c1.selector);
        _assertNode(FacetC.c1.selector, address(facetC), FacetA.a1.selector, bytes4(0));
        _assertFacetASelectors();
        _assertFacetCSelectors();
        _assertRemovalList(FacetA.a1.selector, FacetC.c1.selector, 2, 6);
    }

    function test_ShouldRelink_WhenRemovingTailFacet() external {
        _seedRemovalABC();

        _remove(_singleAddress(address(facetC)));

        _assertFacetCCleared();
        _assertNode(FacetA.a1.selector, address(facetA), bytes4(0), FacetB.b1.selector);
        _assertNode(FacetB.b1.selector, address(facetB), FacetA.a1.selector, bytes4(0));
        _assertFacetASelectors();
        _assertFacetBSelectors();
        _assertRemovalList(FacetA.a1.selector, FacetB.b1.selector, 2, 6);
    }

    function test_ShouldRemoveMultipleFacetsAndEmitInInputOrder() external {
        _seedRemovalABC();
        address[] memory removes = new address[](2);
        removes[0] = address(facetC);
        removes[1] = address(facetA);

        vm.recordLogs();
        _remove(removes);
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 2, "removal log count");
        _assertRemovalLog(logs[0], address(facetC));
        _assertRemovalLog(logs[1], address(facetA));
        _assertFacetACleared();
        _assertFacetCCleared();
        _assertNode(FacetB.b1.selector, address(facetB), bytes4(0), bytes4(0));
        _assertFacetBSelectors();
        _assertRemovalList(FacetB.b1.selector, FacetB.b1.selector, 1, 3);
    }

    function test_ShouldRollBackEarlierRemoval_WhenLaterRemovalFails() external {
        _seedRemovalABC();
        address[] memory removes = new address[](2);
        removes[0] = address(facetA);
        removes[1] = address(facetAReplacement);

        vm.expectRevert(abi.encodeWithSelector(_cannotRemoveFacetThatDoesNotExistError(), address(facetAReplacement)));
        _remove(removes);

        _assertThreeNodeList(address(facetA), address(facetB), address(facetC));
        _assertFacetASelectors();
        _assertFacetBSelectors();
        _assertFacetCSelectors();
        _assertRemovalList(FacetA.a1.selector, FacetC.c1.selector, 3, 9);
    }

    function _remove(address[] memory _facets) private {
        _upgrade(_emptyAddresses(), _emptyReplacements(), _facets, address(0), bytes(""), bytes32(0), bytes(""));
    }

    function _addRemovalFacet(address _facet) private {
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

    function _seedRemovalABC() private {
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

    function _assertOnlyFacetA() private view {
        _assertNode(FacetA.a1.selector, address(facetA), bytes4(0), bytes4(0));
        _assertFacetASelectors();
        _assertRemovalList(FacetA.a1.selector, FacetA.a1.selector, 1, 3);
    }

    function _assertFacetASelectors() private view {
        _assertSelectorOwner(FacetA.a1.selector, address(facetA));
        _assertSelectorOwner(FacetA.a2.selector, address(facetA));
        _assertSelectorOwner(FacetA.a3.selector, address(facetA));
    }

    function _assertFacetBSelectors() private view {
        _assertSelectorOwner(FacetB.b1.selector, address(facetB));
        _assertSelectorOwner(FacetB.b2.selector, address(facetB));
        _assertSelectorOwner(FacetB.b3.selector, address(facetB));
    }

    function _assertFacetCSelectors() private view {
        _assertSelectorOwner(FacetC.c1.selector, address(facetC));
        _assertSelectorOwner(FacetC.c2.selector, address(facetC));
        _assertSelectorOwner(FacetC.c3.selector, address(facetC));
    }

    function _assertFacetACleared() private view {
        _assertNode(FacetA.a1.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetA.a2.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetA.a3.selector, address(0), bytes4(0), bytes4(0));
    }

    function _assertFacetBCleared() private view {
        _assertNode(FacetB.b1.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetB.b2.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetB.b3.selector, address(0), bytes4(0), bytes4(0));
    }

    function _assertFacetCCleared() private view {
        _assertNode(FacetC.c1.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetC.c2.selector, address(0), bytes4(0), bytes4(0));
        _assertNode(FacetC.c3.selector, address(0), bytes4(0), bytes4(0));
    }

    function _assertRemovalList(bytes4 _head, bytes4 _tail, uint32 _facetCount, uint32 _selectorCount) private view {
        (bytes4 head, bytes4 tail, uint32 facetCount, uint32 selectorCount) = target.facetList();
        assertEq(head, _head, "head");
        assertEq(tail, _tail, "tail");
        assertEq(facetCount, _facetCount, "facetCount");
        assertEq(selectorCount, _selectorCount, "selectorCount");
    }

    function _assertRemovalLog(Vm.Log memory _log, address _facet) private view {
        assertEq(_log.emitter, target, "removal emitter");
        assertEq(_log.topics.length, 2, "removal topic count");
        assertEq(_log.topics[0], FACET_REMOVED_TOPIC, "removal topic");
        assertEq(address(uint160(uint256(_log.topics[1]))), _facet, "removed facet");
        assertEq(_log.data.length, 0, "removal data length");
    }
}
