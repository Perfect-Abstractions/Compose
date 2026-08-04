// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {DiamondUpgrade_Base_Test} from "test/unit/diamond/DiamondUpgradeBase.t.sol";
import {
    BadOffsetFacet,
    EmptySelectorsFacet,
    MisalignedSelectorsFacet,
    OversizedLengthFacet,
    RevertingSelectorsFacet,
    ShortReturnFacet
} from "test/utils/mocks/diamond/DiamondFacetMocks.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
abstract contract AddFacetsBehavior is DiamondUpgrade_Base_Test {
    function _noBytecodeAtAddressError() internal pure virtual returns (bytes4);

    function _exportSelectorsCallFailedError() internal pure virtual returns (bytes4);

    function _noSelectorsForFacetError() internal pure virtual returns (bytes4);

    function _incorrectSelectorsEncodingError() internal pure virtual returns (bytes4);

    function test_ShouldNotChangeState_WhenAddArrayIsEmpty() external {
        _upgrade(
            _emptyAddresses(), _emptyReplacements(), _emptyAddresses(), address(0), bytes(""), bytes32(0), bytes("")
        );
        _assertCounts(0, 0);
    }

    function test_ShouldAddAndLinkThreeFacets() external {
        _upgrade(
            _threeFacets(address(facetA), address(facetB), address(facetC)),
            _emptyReplacements(),
            _emptyAddresses(),
            address(0),
            bytes(""),
            bytes32(0),
            bytes("")
        );
        _assertThreeNodeList(address(facetA), address(facetB), address(facetC));
        _assertCounts(3, 9);
    }

    function test_RevertWhen_AddFacetHasNoBytecode() external {
        address badFacet = makeAddr("no-code");

        vm.expectRevert(abi.encodeWithSelector(_noBytecodeAtAddressError(), badFacet));
        _addFacet(badFacet);
    }

    function test_RevertWhen_AddFacetExportSelectorsCallFails() external {
        address badFacet = address(new RevertingSelectorsFacet());

        vm.expectRevert(abi.encodeWithSelector(_exportSelectorsCallFailedError(), badFacet));
        _addFacet(badFacet);
    }

    function test_RevertWhen_AddFacetReturnsNoSelectors() external {
        address badFacet = address(new EmptySelectorsFacet());

        vm.expectRevert(abi.encodeWithSelector(_noSelectorsForFacetError(), badFacet));
        _addFacet(badFacet);
    }

    function test_RevertWhen_AddFacetSelectorReturnDataIsTooShort() external {
        address badFacet = address(new ShortReturnFacet());

        vm.expectRevert(abi.encodeWithSelector(_incorrectSelectorsEncodingError(), badFacet));
        _addFacet(badFacet);
    }

    function test_RevertWhen_AddFacetSelectorReturnDataHasBadOffset() external {
        address badFacet = address(new BadOffsetFacet());

        vm.expectRevert(abi.encodeWithSelector(_incorrectSelectorsEncodingError(), badFacet));
        _addFacet(badFacet);
    }

    function test_RevertWhen_AddFacetSelectorLengthExceedsPayload() external {
        address badFacet = address(new OversizedLengthFacet());

        vm.expectRevert(abi.encodeWithSelector(_incorrectSelectorsEncodingError(), badFacet));
        _addFacet(badFacet);
    }

    function test_RevertWhen_AddFacetSelectorLengthIsMisaligned() external {
        address badFacet = address(new MisalignedSelectorsFacet());

        vm.expectRevert(abi.encodeWithSelector(_incorrectSelectorsEncodingError(), badFacet));
        _addFacet(badFacet);
    }

    function _addFacet(address _facet) private {
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
}
