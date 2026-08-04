// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {DiamondModHarness} from "test/utils/harnesses/diamond/DiamondModHarness.sol";
import {
    DelegateTarget,
    FacetA,
    FacetAChanged,
    FacetAReplacement,
    FacetB,
    FacetBChanged,
    FacetBReplacement,
    FacetC,
    FacetCChanged,
    FacetCReplacement
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";
import {DiamondStorageUtils} from "test/utils/storage/DiamondStorageUtils.sol";

struct Replacement {
    address oldFacet;
    address newFacet;
}

abstract contract DiamondUpgrade_Base_Test is Base_Test {
    using DiamondStorageUtils for address;

    event FacetAdded(address indexed _facet);
    event FacetReplaced(address indexed _oldFacet, address indexed _newFacet);
    event FacetRemoved(address indexed _facet);
    event DiamondDelegateCall(address indexed _delegate, bytes _delegateCalldata);
    event DiamondMetadata(bytes32 indexed _tag, bytes _data);

    address internal target;
    FacetA internal facetA;
    FacetAReplacement internal facetAReplacement;
    FacetAChanged internal facetAChanged;
    FacetB internal facetB;
    FacetBReplacement internal facetBReplacement;
    FacetBChanged internal facetBChanged;
    FacetC internal facetC;
    FacetCReplacement internal facetCReplacement;
    FacetCChanged internal facetCChanged;
    DelegateTarget internal delegateTarget;

    function setUp() public virtual override {
        Base_Test.setUp();
        facetA = new FacetA();
        facetAReplacement = new FacetAReplacement();
        facetAChanged = new FacetAChanged();
        facetB = new FacetB();
        facetBReplacement = new FacetBReplacement();
        facetBChanged = new FacetBChanged();
        facetC = new FacetC();
        facetCReplacement = new FacetCReplacement();
        facetCChanged = new FacetCChanged();
        delegateTarget = new DelegateTarget();
    }

    function _upgrade(
        address[] memory _adds,
        Replacement[] memory _replacements,
        address[] memory _removes,
        address _delegate,
        bytes memory _delegateCalldata,
        bytes32 _tag,
        bytes memory _metadata
    ) internal virtual;

    function _assertCounts(uint32 _facets, uint32 _selectors) internal view {
        (,, uint32 facetCount, uint32 selectorCount) = target.facetList();
        assertEq(facetCount, _facets, "facetCount");
        assertEq(selectorCount, _selectors, "selectorCount");
    }

    function _emptyAddresses() internal pure returns (address[] memory values) {
        values = new address[](0);
    }

    function _emptyReplacements() internal pure returns (Replacement[] memory values) {
        values = new Replacement[](0);
    }

    function _singleAddress(address _value) internal pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = _value;
    }

    function _singleReplacement(address _oldFacet, address _newFacet)
        internal
        pure
        returns (Replacement[] memory values)
    {
        values = new Replacement[](1);
        values[0] = Replacement(_oldFacet, _newFacet);
    }

    function _threeFacets(address _a, address _b, address _c) internal pure returns (address[] memory values) {
        values = new address[](3);
        values[0] = _a;
        values[1] = _b;
        values[2] = _c;
    }

    function _assertSelectorOwner(bytes4 _selector, address _expectedFacet) internal view {
        (address actualFacet,,) = DiamondStorageUtils.facetNode(target, _selector);
        assertEq(actualFacet, _expectedFacet, "selector owner");
    }

    function _assertNode(bytes4 _selector, address _facet, bytes4 _prev, bytes4 _next) internal view {
        (address actualFacet, bytes4 actualPrev, bytes4 actualNext) = DiamondStorageUtils.facetNode(target, _selector);
        assertEq(actualFacet, _facet, "node facet");
        assertEq(actualPrev, _prev, "node prev");
        assertEq(actualNext, _next, "node next");
    }

    function _assertThreeNodeList(address _a, address _b, address _c) internal view {
        _assertNode(FacetA.a1.selector, _a, bytes4(0), FacetB.b1.selector);
        _assertNode(FacetB.b1.selector, _b, FacetA.a1.selector, FacetC.c1.selector);
        _assertNode(FacetC.c1.selector, _c, FacetB.b1.selector, bytes4(0));
    }
}

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract DiamondStorageLayout_Unit_Test is Base_Test {
    function test_ShouldProveStorageBitOffsets() external {
        FacetA facetA = new FacetA();
        address[] memory facets = new address[](1);
        facets[0] = address(facetA);
        DiamondModHarness harness = new DiamondModHarness(facets);

        (bytes4 head, bytes4 tail, uint32 facetCount, uint32 selectorCount) =
            DiamondStorageUtils.facetList(address(harness));
        assertEq(head, FacetA.a1.selector, "head");
        assertEq(tail, FacetA.a1.selector, "tail");
        assertEq(facetCount, 1, "facetCount");
        assertEq(selectorCount, 3, "selectorCount");

        (address facet, bytes4 prev, bytes4 next) = DiamondStorageUtils.facetNode(address(harness), FacetA.a1.selector);
        assertEq(facet, address(facetA), "node facet");
        assertEq(prev, bytes4(0), "node prev");
        assertEq(next, bytes4(0), "node next");

        (facet,,) = DiamondStorageUtils.facetNode(address(harness), FacetA.a2.selector);
        assertEq(facet, address(facetA), "non-head owner");
    }
}
