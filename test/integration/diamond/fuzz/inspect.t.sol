// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {DiamondInspectFacet} from "src/diamond/DiamondInspectFacet.sol";
import {Diamond_Base_Test, IDiamondInspect} from "test/integration/diamond/DiamondBase.t.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract Inspect_DiamondInspectFacet_Fuzz_Integration_Test is Diamond_Base_Test {
    function test_ShouldReturnEmptyViews_WhenNoFacetsAreRegistered() external view {
        assertEq(isolatedInspectFacet.facetAddress(bytes4(keccak256("unknown()"))), address(0), "unknown selector");
        assertEq(isolatedInspectFacet.facetAddresses().length, 0, "facet addresses");
        assertEq(isolatedInspectFacet.facets().length, 0, "facets");
    }

    function test_ShouldReturnEmptySelectors_ForValidUnregisteredFacet() external view {
        bytes4[] memory selectors = inspect.facetFunctionSelectors(address(facetA));

        assertEq(selectors.length, 0, "unregistered facet selectors");
    }

    function test_ShouldReturnFacetAddress_ForEveryRegisteredSelector() external {
        _addFacets(address(facetA), address(facetB), address(facetC));

        _assertFacetOwnsPackedSelectors(address(upgradeFacet), _upgradeSelectors());
        _assertFacetOwnsPackedSelectors(address(inspectFacet), _inspectSelectors());
        _assertFacetOwnsPackedSelectors(address(facetA), facetA.exportSelectors());
        _assertFacetOwnsPackedSelectors(address(facetB), facetB.exportSelectors());
        _assertFacetOwnsPackedSelectors(address(facetC), facetC.exportSelectors());
        assertEq(inspect.facetAddress(bytes4(keccak256("unknown()"))), address(0), "unknown selector");
    }

    function test_ShouldReturnFacetSelectors_InExportOrder() external {
        _addFacets(address(facetA), address(facetB), address(facetC));

        _assertSelectors(inspect.facetFunctionSelectors(address(upgradeFacet)), _upgradeSelectors(), "upgrade");
        _assertSelectors(inspect.facetFunctionSelectors(address(inspectFacet)), _inspectSelectors(), "inspect");
        _assertSelectors(inspect.facetFunctionSelectors(address(facetA)), facetA.exportSelectors(), "facet A");
        _assertSelectors(inspect.facetFunctionSelectors(address(facetB)), facetB.exportSelectors(), "facet B");
        _assertSelectors(inspect.facetFunctionSelectors(address(facetC)), facetC.exportSelectors(), "facet C");
    }

    function test_ShouldReturnFacetAddresses_InLinkedListOrder() external {
        _addFacets(address(facetA), address(facetB), address(facetC));

        address[] memory expected = new address[](5);
        expected[0] = address(upgradeFacet);
        expected[1] = address(inspectFacet);
        expected[2] = address(facetA);
        expected[3] = address(facetB);
        expected[4] = address(facetC);
        assertEq(inspect.facetAddresses(), expected, "facet address order");
    }

    function test_ShouldReturnFacets_PairedWithExactSelectors() external {
        _addFacets(address(facetA), address(facetB), address(facetC));

        IDiamondInspect.Facet[] memory inspectedFacets = inspect.facets();
        assertEq(inspectedFacets.length, 5, "facet count");
        _assertInspectedFacet(inspectedFacets[0], address(upgradeFacet), _upgradeSelectors(), "upgrade");
        _assertInspectedFacet(inspectedFacets[1], address(inspectFacet), _inspectSelectors(), "inspect");
        _assertInspectedFacet(inspectedFacets[2], address(facetA), facetA.exportSelectors(), "facet A");
        _assertInspectedFacet(inspectedFacets[3], address(facetB), facetB.exportSelectors(), "facet B");
        _assertInspectedFacet(inspectedFacets[4], address(facetC), facetC.exportSelectors(), "facet C");
    }

    function test_ShouldExcludeRemovedFacetAndSelectors_FromEveryInspectionView() external {
        _addFacets(address(facetA), address(facetB), address(facetC));
        _removeFacet(address(facetB));

        bytes memory removedSelectors = facetB.exportSelectors();
        for (uint256 i; i < removedSelectors.length / 4; i++) {
            assertEq(inspect.facetAddress(_selectorAt(removedSelectors, i)), address(0), "removed selector owner");
        }
        assertEq(inspect.facetFunctionSelectors(address(facetB)).length, 0, "removed facet selectors");

        address[] memory expectedAddresses = new address[](4);
        expectedAddresses[0] = address(upgradeFacet);
        expectedAddresses[1] = address(inspectFacet);
        expectedAddresses[2] = address(facetA);
        expectedAddresses[3] = address(facetC);
        assertEq(inspect.facetAddresses(), expectedAddresses, "addresses after removal");

        IDiamondInspect.Facet[] memory inspectedFacets = inspect.facets();
        assertEq(inspectedFacets.length, 4, "facets after removal");
        _assertInspectedFacet(inspectedFacets[0], address(upgradeFacet), _upgradeSelectors(), "upgrade");
        _assertInspectedFacet(inspectedFacets[1], address(inspectFacet), _inspectSelectors(), "inspect");
        _assertInspectedFacet(inspectedFacets[2], address(facetA), facetA.exportSelectors(), "facet A");
        _assertInspectedFacet(inspectedFacets[3], address(facetC), facetC.exportSelectors(), "facet C");
    }

    function test_ShouldReturnEmptySelectors_ForFacetReplacedWithSameSelectorSet() external {
        _addFacet(address(facetA));
        _replaceFacet(address(facetA), address(facetAReplacement));

        bytes4[] memory oldSelectors = inspect.facetFunctionSelectors(address(facetA));
        bytes4[] memory newSelectors = inspect.facetFunctionSelectors(address(facetAReplacement));

        assertEq(oldSelectors.length, 0, "old facet selectors");
        assertEq(newSelectors.length, 3, "replacement selectors");
    }

    function test_ShouldExportInspectionSelectors_InDeclarationOrder() external view {
        assertEq(
            inspectFacet.exportSelectors(),
            bytes.concat(
                DiamondInspectFacet.facetAddress.selector,
                DiamondInspectFacet.facetFunctionSelectors.selector,
                DiamondInspectFacet.facetAddresses.selector,
                DiamondInspectFacet.facets.selector
            )
        );
    }

    function _assertFacetOwnsPackedSelectors(address _facet, bytes memory _packedSelectors) private view {
        for (uint256 i; i < _packedSelectors.length / 4; i++) {
            assertEq(inspect.facetAddress(_selectorAt(_packedSelectors, i)), _facet, "selector owner");
        }
    }

    function _assertInspectedFacet(
        IDiamondInspect.Facet memory _actual,
        address _expectedAddress,
        bytes memory _expectedSelectors,
        string memory _message
    ) private pure {
        assertEq(_actual.facet, _expectedAddress, string.concat(_message, " address"));
        _assertSelectors(_actual.functionSelectors, _expectedSelectors, _message);
    }

    function _selectorAt(bytes memory _packedSelectors, uint256 _index) private pure returns (bytes4 selector) {
        assembly ("memory-safe") {
            selector := mload(add(add(_packedSelectors, 0x20), mul(_index, 4)))
        }
    }
}
