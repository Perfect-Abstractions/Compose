// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {DiamondInspectFacet} from "src/diamond/DiamondInspectFacet.sol";
import {DiamondUpgradeFacet} from "src/diamond/DiamondUpgradeFacet.sol";
import {Diamond_Base_Test, IDiamondInspect} from "test/integration/diamond/DiamondBase.t.sol";
import {
    FacetA,
    FacetAReplacement,
    FacetB,
    FacetBReplacement,
    FacetC,
    FacetCReplacement
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";
import {DiamondStorageUtils} from "test/utils/storage/DiamondStorageUtils.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract Sequences_Diamond_Fuzz_Integration_Test is Diamond_Base_Test {
    uint256 private constant MAX_ACTIONS = 24;
    uint256 private constant BASELINE_FACET_COUNT = 2;
    uint256 private constant BASELINE_SELECTOR_COUNT = 5;

    struct FamilyModel {
        address original;
        address replacement;
        address currentFacet;
        bytes selectors;
        bool registered;
    }

    struct SequenceModel {
        FamilyModel[3] families;
        uint8[3] order;
        uint8 activeCount;
    }

    FacetBReplacement internal facetBReplacement;
    FacetCReplacement internal facetCReplacement;

    function setUp() public override {
        super.setUp();

        facetBReplacement = new FacetBReplacement();
        facetCReplacement = new FacetCReplacement();
    }

    function test_AddReplaceRemove_AllUserFacets() external {
        _runDeterministic(hex"000306010407020508");
    }

    function test_RemoveHeadThenAppend_ReusesValidTailLinks() external {
        _runDeterministic(hex"0003060200");
    }

    function test_RemoveTailThenAppend_UsesPreviousTail() external {
        _runDeterministic(hex"0003060806");
    }

    function test_ReplaceMiddleThenRemoveNeighbors_PreservesSingleton() external {
        _runDeterministic(hex"000306040208");
    }

    function test_RemoveAllThenReAddInDifferentOrder_RebuildsList() external {
        _runDeterministic(hex"000306020508060003");
    }

    function testFuzz_AddReplaceRemove_SequenceMatchesModel(bytes calldata _actions) external {
        SequenceModel memory model = _newModel();
        _assertModel(model);

        uint256 steps = bound(_actions.length, 0, MAX_ACTIONS);
        for (uint256 i; i < steps; i++) {
            uint8 action = uint8(_actions[i]) % 9;
            _applyAction(model, action);
            _assertModel(model);
        }
    }

    function _runDeterministic(bytes memory _actions) private {
        assertLe(_actions.length, MAX_ACTIONS, "deterministic action bound");

        SequenceModel memory model = _newModel();
        _assertModel(model);
        for (uint256 i; i < _actions.length; i++) {
            _applyAction(model, uint8(_actions[i]) % 9);
            _assertModel(model);
        }
    }

    function _newModel() private view returns (SequenceModel memory model) {
        model.families[0] = FamilyModel({
            original: address(facetA),
            replacement: address(facetAReplacement),
            currentFacet: address(facetA),
            selectors: bytes.concat(FacetA.a1.selector, FacetA.a2.selector, FacetA.a3.selector),
            registered: false
        });
        model.families[1] = FamilyModel({
            original: address(facetB),
            replacement: address(facetBReplacement),
            currentFacet: address(facetB),
            selectors: bytes.concat(FacetB.b1.selector, FacetB.b2.selector, FacetB.b3.selector),
            registered: false
        });
        model.families[2] = FamilyModel({
            original: address(facetC),
            replacement: address(facetCReplacement),
            currentFacet: address(facetC),
            selectors: bytes.concat(FacetC.c1.selector, FacetC.c2.selector, FacetC.c3.selector),
            registered: false
        });
    }

    function _applyAction(SequenceModel memory _model, uint8 _action) private {
        uint8 family = _action / 3;
        uint8 operation = _action % 3;
        FamilyModel memory familyModel = _model.families[family];

        if (operation == 0 && !familyModel.registered) {
            _addFacet(familyModel.currentFacet);
            _model.families[family].registered = true;
            _model.order[_model.activeCount] = family;
            _model.activeCount++;
        } else if (operation == 1 && familyModel.registered) {
            address replacement;
            if (familyModel.currentFacet == familyModel.original) {
                replacement = familyModel.replacement;
            } else {
                replacement = familyModel.original;
            }
            _replaceFacet(familyModel.currentFacet, replacement);
            _model.families[family].currentFacet = replacement;
        } else if (operation == 2 && familyModel.registered) {
            _removeFacet(familyModel.currentFacet);
            _model.families[family].registered = false;
            _removeFromOrder(_model, family);
        }
    }

    function _removeFromOrder(SequenceModel memory _model, uint8 _family) private pure {
        uint256 removeIndex;
        for (uint256 i; i < _model.activeCount; i++) {
            if (_model.order[i] == _family) {
                removeIndex = i;
                break;
            }
        }
        for (uint256 i = removeIndex; i + 1 < _model.activeCount; i++) {
            _model.order[i] = _model.order[i + 1];
        }
        _model.activeCount--;
    }

    function _assertModel(SequenceModel memory _model) private view {
        uint256 expectedFacetCount = BASELINE_FACET_COUNT + _model.activeCount;
        uint256 expectedSelectorCount = BASELINE_SELECTOR_COUNT + uint256(_model.activeCount) * 3;

        _assertRoutesAndFacetSelectors(_model);
        _assertCountsAndTraversal(_model, expectedFacetCount, expectedSelectorCount);
        _assertInspectionViews(_model, expectedFacetCount);
    }

    function _assertRoutesAndFacetSelectors(SequenceModel memory _model) private view {
        _assertFacetRoutes(address(upgradeFacet), _upgradeSelectors());
        _assertFacetRoutes(address(inspectFacet), _inspectSelectors());

        for (uint256 family; family < _model.families.length; family++) {
            FamilyModel memory familyModel = _model.families[family];
            address expectedOwner = familyModel.registered ? familyModel.currentFacet : address(0);
            for (uint256 selectorIndex; selectorIndex < 3; selectorIndex++) {
                assertEq(
                    inspect.facetAddress(_selectorAt(familyModel.selectors, selectorIndex)),
                    expectedOwner,
                    "model selector owner"
                );
            }

            if (familyModel.registered && familyModel.currentFacet == familyModel.original) {
                _assertSelectors(
                    inspect.facetFunctionSelectors(familyModel.original), familyModel.selectors, "active original"
                );
                assertEq(
                    inspect.facetFunctionSelectors(familyModel.replacement).length, 0, "inactive replacement selectors"
                );
            } else if (familyModel.registered) {
                assertEq(inspect.facetFunctionSelectors(familyModel.original).length, 0, "replaced old facet selectors");
                _assertSelectors(
                    inspect.facetFunctionSelectors(familyModel.replacement), familyModel.selectors, "active replacement"
                );
            } else {
                assertEq(inspect.facetFunctionSelectors(familyModel.original).length, 0, "removed original selectors");
                assertEq(
                    inspect.facetFunctionSelectors(familyModel.replacement).length, 0, "removed replacement selectors"
                );
            }
        }
    }

    function _assertFacetRoutes(address _expectedFacet, bytes memory _selectors) private view {
        for (uint256 i; i < _selectors.length / 4; i++) {
            assertEq(inspect.facetAddress(_selectorAt(_selectors, i)), _expectedFacet, "baseline selector owner");
        }
    }

    function _assertCountsAndTraversal(
        SequenceModel memory _model,
        uint256 _expectedFacetCount,
        uint256 _expectedSelectorCount
    ) private view {
        (bytes4 head, bytes4 tail, uint32 facetCount, uint32 selectorCount) =
            DiamondStorageUtils.facetList(address(proxy));
        assertEq(uint256(facetCount), _expectedFacetCount, "model facetCount");
        assertEq(uint256(selectorCount), _expectedSelectorCount, "model selectorCount");
        assertEq(
            uint256(selectorCount) - BASELINE_SELECTOR_COUNT,
            uint256(_model.activeCount) * 3,
            "active family selectorCount"
        );

        bytes4[] memory visited = new bytes4[](_expectedFacetCount);
        bytes4 current = head;
        bytes4 previous;
        for (uint256 i; i < _expectedFacetCount; i++) {
            for (uint256 visitedIndex; visitedIndex < i; visitedIndex++) {
                assertTrue(visited[visitedIndex] != current, "traversal node uniqueness");
            }
            visited[i] = current;
            current = _assertTraversalNode(_model, i, current, previous, _expectedFacetCount);
            previous = visited[i];
        }

        assertEq(head, visited[0], "model head");
        assertEq(tail, visited[_expectedFacetCount - 1], "model tail");
        assertEq(current, bytes4(0), "traversal terminates after facetCount");
    }

    function _assertTraversalNode(
        SequenceModel memory _model,
        uint256 _index,
        bytes4 _current,
        bytes4 _previous,
        uint256 _expectedFacetCount
    ) private view returns (bytes4 actualNext) {
        assertEq(_current, _expectedNodeAt(_model, _index), "model traversal node");

        (address actualFacet, bytes4 actualPrev, bytes4 next) = DiamondStorageUtils.facetNode(address(proxy), _current);
        assertEq(actualFacet, _expectedFacetAt(_model, _index), "model traversal facet");
        assertEq(actualPrev, _previous, "model previous link");

        bytes4 expectedNext = _index + 1 < _expectedFacetCount ? _expectedNodeAt(_model, _index + 1) : bytes4(0);
        assertEq(next, expectedNext, "model next link");
        actualNext = next;
    }

    function _assertInspectionViews(SequenceModel memory _model, uint256 _expectedFacetCount) private view {
        address[] memory expectedAddresses = new address[](_expectedFacetCount);
        for (uint256 i; i < _expectedFacetCount; i++) {
            expectedAddresses[i] = _expectedFacetAt(_model, i);
        }
        assertEq(inspect.facetAddresses(), expectedAddresses, "model facet addresses");

        IDiamondInspect.Facet[] memory actualFacets = inspect.facets();
        assertEq(actualFacets.length, _expectedFacetCount, "model facets length");
        for (uint256 i; i < _expectedFacetCount; i++) {
            assertEq(actualFacets[i].facet, expectedAddresses[i], "model facets address");
            _assertSelectors(
                actualFacets[i].functionSelectors, _expectedSelectorsAt(_model, i), "model facets selectors"
            );
        }
    }

    function _expectedFacetAt(SequenceModel memory _model, uint256 _index) private view returns (address) {
        if (_index == 0) {
            return address(upgradeFacet);
        }
        if (_index == 1) {
            return address(inspectFacet);
        }
        return _model.families[_model.order[_index - BASELINE_FACET_COUNT]].currentFacet;
    }

    function _expectedNodeAt(SequenceModel memory _model, uint256 _index) private pure returns (bytes4) {
        if (_index == 0) {
            return DiamondUpgradeFacet.upgradeDiamond.selector;
        }
        if (_index == 1) {
            return DiamondInspectFacet.facetAddress.selector;
        }

        uint8 family = _model.order[_index - BASELINE_FACET_COUNT];
        if (family == 0) {
            return FacetA.a1.selector;
        }
        if (family == 1) {
            return FacetB.b1.selector;
        }
        return FacetC.c1.selector;
    }

    function _expectedSelectorsAt(SequenceModel memory _model, uint256 _index) private pure returns (bytes memory) {
        if (_index == 0) {
            return bytes.concat(DiamondUpgradeFacet.upgradeDiamond.selector);
        }
        if (_index == 1) {
            return bytes.concat(
                DiamondInspectFacet.facetAddress.selector,
                DiamondInspectFacet.facetFunctionSelectors.selector,
                DiamondInspectFacet.facetAddresses.selector,
                DiamondInspectFacet.facets.selector
            );
        }
        return _model.families[_model.order[_index - BASELINE_FACET_COUNT]].selectors;
    }

    function _selectorAt(bytes memory _selectors, uint256 _index) private pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            selector := mload(add(add(_selectors, 0x20), mul(_index, 4)))
        }
    }
}
