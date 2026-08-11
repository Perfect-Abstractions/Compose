// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {DiamondModHarness} from "test/utils/harnesses/diamond/DiamondModHarness.sol";
import {DispatchFacet, FacetA, FacetB, FacetC} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";
import {DiamondStorageUtils} from "test/utils/storage/DiamondStorageUtils.sol";

abstract contract DiamondMod_Base_Test is Base_Test {
    event FacetAdded(address indexed _facet);

    DiamondModHarness internal harness;
    FacetA internal facetA;
    FacetB internal facetB;
    FacetC internal facetC;
    DispatchFacet internal dispatchFacet;

    function setUp() public virtual override {
        Base_Test.setUp();
        harness = new DiamondModHarness(_emptyAddresses());
        facetA = new FacetA();
        facetB = new FacetB();
        facetC = new FacetC();
        dispatchFacet = new DispatchFacet();
    }

    function _emptyAddresses() internal pure returns (address[] memory values) {
        values = new address[](0);
    }

    function _singleAddress(address _value) internal pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = _value;
    }

    function _threeFacets(address _a, address _b, address _c) internal pure returns (address[] memory values) {
        values = new address[](3);
        values[0] = _a;
        values[1] = _b;
        values[2] = _c;
    }

    function _assertFacetList(
        address _target,
        bytes4 _expectedHead,
        bytes4 _expectedTail,
        uint32 _expectedFacetCount,
        uint32 _expectedSelectorCount
    ) internal view {
        (bytes4 head, bytes4 tail, uint32 facetCount, uint32 selectorCount) = DiamondStorageUtils.facetList(_target);
        assertEq(head, _expectedHead, "head");
        assertEq(tail, _expectedTail, "tail");
        assertEq(facetCount, _expectedFacetCount, "facetCount");
        assertEq(selectorCount, _expectedSelectorCount, "selectorCount");
    }

    function _assertNode(
        address _target,
        bytes4 _selector,
        address _expectedFacet,
        bytes4 _expectedPrev,
        bytes4 _expectedNext
    ) internal view {
        (address facet, bytes4 prev, bytes4 next) = DiamondStorageUtils.facetNode(_target, _selector);
        assertEq(facet, _expectedFacet, "node facet");
        assertEq(prev, _expectedPrev, "node prev");
        assertEq(next, _expectedNext, "node next");
    }
}
