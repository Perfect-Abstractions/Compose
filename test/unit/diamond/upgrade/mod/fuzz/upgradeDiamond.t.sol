// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import "src/diamond/DiamondUpgradeMod.sol" as DiamondUpgradeMod;
import {DiamondUpgrade_Base_Test, Replacement} from "test/unit/diamond/DiamondUpgradeBase.t.sol";
import {AddFacetsBehavior} from "test/unit/diamond/upgrade/shared/AddFacetsBehavior.t.sol";
import {RemoveFacetsBehavior} from "test/unit/diamond/upgrade/shared/RemoveFacetsBehavior.t.sol";
import {ReplaceFacetsBehavior} from "test/unit/diamond/upgrade/shared/ReplaceFacetsBehavior.t.sol";
import {DiamondUpgradeModHarness} from "test/utils/harnesses/diamond/DiamondUpgradeModHarness.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract UpgradeDiamond_DiamondUpgradeMod_Fuzz_Unit_Test is
    AddFacetsBehavior,
    ReplaceFacetsBehavior,
    RemoveFacetsBehavior
{
    DiamondUpgradeModHarness internal harness;

    function setUp() public override(DiamondUpgrade_Base_Test) {
        super.setUp();
        harness = new DiamondUpgradeModHarness();
        target = address(harness);
        vm.label(target, "DiamondUpgradeModHarness");
    }

    function _upgrade(
        address[] memory _adds,
        Replacement[] memory _replacements,
        address[] memory _removes,
        address _delegate,
        bytes memory _delegateCalldata,
        bytes32 _tag,
        bytes memory _metadata
    ) internal override {
        DiamondUpgradeMod.FacetReplacement[] memory replacements =
            new DiamondUpgradeMod.FacetReplacement[](_replacements.length);
        for (uint256 i; i < _replacements.length; i++) {
            replacements[i] = DiamondUpgradeMod.FacetReplacement({
                oldFacet: _replacements[i].oldFacet, newFacet: _replacements[i].newFacet
            });
        }

        harness.upgradeDiamond(_adds, replacements, _removes, _delegate, _delegateCalldata, _tag, _metadata);
    }

    function _noBytecodeAtAddressError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.NoBytecodeAtAddress.selector;
    }

    function _exportSelectorsCallFailedError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.ExportSelectorsCallFailed.selector;
    }

    function _noSelectorsForFacetError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.NoSelectorsForFacet.selector;
    }

    function _incorrectSelectorsEncodingError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.IncorrectSelectorsEncoding.selector;
    }

    function _cannotReplaceFacetWithSameFacetError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.CannotReplaceFacetWithSameFacet.selector;
    }

    function _facetToReplaceDoesNotExistError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.FacetToReplaceDoesNotExist.selector;
    }

    function _cannotReplaceFunctionFromNonReplacementFacetError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.CannotReplaceFunctionFromNonReplacementFacet.selector;
    }

    function _cannotRemoveFacetThatDoesNotExistError() internal pure override returns (bytes4) {
        return DiamondUpgradeMod.CannotRemoveFacetThatDoesNotExist.selector;
    }
}
