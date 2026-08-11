// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import "src/diamond/DiamondMod.sol" as DiamondMod;
import {DiamondMod_Base_Test} from "test/unit/diamond/DiamondModBase.t.sol";
import {
    BadOffsetFacet,
    EmptySelectorsFacet,
    FacetA,
    MisalignedSelectorsFacet,
    OversizedLengthFacet,
    RevertingSelectorsFacet,
    ShortReturnFacet
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract ImportSelectors_DiamondMod_Fuzz_Unit_Test is DiamondMod_Base_Test {
    function test_RevertWhen_FacetHasNoBytecode() external {
        address noCode = makeAddr("no-code");

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.NoBytecodeAtAddress.selector, noCode));
        harness.addFacets(_singleAddress(noCode));
    }

    function test_RevertWhen_ExportSelectorsCallFails() external {
        address badFacet = address(new RevertingSelectorsFacet());

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.FunctionSelectorsCallFailed.selector, badFacet));
        harness.addFacets(_singleAddress(badFacet));
    }

    function test_RevertWhen_NoSelectorsAreReturned() external {
        address badFacet = address(new EmptySelectorsFacet());

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.NoSelectorsForFacet.selector, badFacet));
        harness.addFacets(_singleAddress(badFacet));
    }

    function test_RevertWhen_ReturnDataIsTooShort() external {
        address badFacet = address(new ShortReturnFacet());

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.IncorrectSelectorsEncoding.selector, badFacet));
        harness.addFacets(_singleAddress(badFacet));
    }

    function test_RevertWhen_ReturnDataHasBadOffset() external {
        address badFacet = address(new BadOffsetFacet());

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.IncorrectSelectorsEncoding.selector, badFacet));
        harness.addFacets(_singleAddress(badFacet));
    }

    function test_RevertWhen_SelectorLengthExceedsPayload() external {
        address badFacet = address(new OversizedLengthFacet());

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.IncorrectSelectorsEncoding.selector, badFacet));
        harness.addFacets(_singleAddress(badFacet));
    }

    function test_RevertWhen_SelectorLengthIsMisaligned() external {
        address badFacet = address(new MisalignedSelectorsFacet());

        vm.expectRevert(abi.encodeWithSelector(DiamondMod.IncorrectSelectorsEncoding.selector, badFacet));
        harness.addFacets(_singleAddress(badFacet));
    }

    function test_ShouldImportEverySelectorInExportOrder() external {
        harness.addFacets(_singleAddress(address(facetA)));

        _assertFacetList(address(harness), FacetA.a1.selector, FacetA.a1.selector, 1, 3);
        _assertNode(address(harness), FacetA.a1.selector, address(facetA), bytes4(0), bytes4(0));
        _assertNode(address(harness), FacetA.a2.selector, address(facetA), bytes4(0), bytes4(0));
        _assertNode(address(harness), FacetA.a3.selector, address(facetA), bytes4(0), bytes4(0));
    }
}
