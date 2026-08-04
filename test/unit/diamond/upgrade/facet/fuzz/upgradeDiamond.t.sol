// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {DiamondUpgradeFacet} from "src/diamond/DiamondUpgradeFacet.sol";
import {DiamondUpgrade_Base_Test, Replacement} from "test/unit/diamond/DiamondUpgradeBase.t.sol";
import {AddFacetsBehavior} from "test/unit/diamond/upgrade/shared/AddFacetsBehavior.t.sol";
import {RemoveFacetsBehavior} from "test/unit/diamond/upgrade/shared/RemoveFacetsBehavior.t.sol";
import {ReplaceFacetsBehavior} from "test/unit/diamond/upgrade/shared/ReplaceFacetsBehavior.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";

/**
 * @dev BTT spec: test/trees/Diamond.tree
 */
contract UpgradeDiamond_DiamondUpgradeFacet_Fuzz_Unit_Test is
    AddFacetsBehavior,
    ReplaceFacetsBehavior,
    RemoveFacetsBehavior
{
    DiamondUpgradeFacet internal upgradeFacet;

    function setUp() public override(DiamondUpgrade_Base_Test) {
        super.setUp();
        upgradeFacet = new DiamondUpgradeFacet();
        target = address(upgradeFacet);
        vm.label(target, "DiamondUpgradeFacet");
        OwnerStorageUtils.setOwner(target, users.alice);
        vm.stopPrank();
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
        DiamondUpgradeFacet.FacetReplacement[] memory replacements =
            new DiamondUpgradeFacet.FacetReplacement[](_replacements.length);
        for (uint256 i; i < _replacements.length; i++) {
            replacements[i] = DiamondUpgradeFacet.FacetReplacement({
                oldFacet: _replacements[i].oldFacet, newFacet: _replacements[i].newFacet
            });
        }

        vm.prank(users.alice);
        upgradeFacet.upgradeDiamond(_adds, replacements, _removes, _delegate, _delegateCalldata, _tag, _metadata);
    }

    function _noBytecodeAtAddressError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.NoBytecodeAtAddress.selector;
    }

    function _exportSelectorsCallFailedError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.ExportSelectorsCallFailed.selector;
    }

    function _noSelectorsForFacetError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.NoSelectorsForFacet.selector;
    }

    function _incorrectSelectorsEncodingError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.IncorrectSelectorsEncoding.selector;
    }

    function _cannotReplaceFacetWithSameFacetError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.CannotReplaceFacetWithSameFacet.selector;
    }

    function _facetToReplaceDoesNotExistError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.FacetToReplaceDoesNotExist.selector;
    }

    function _cannotReplaceFunctionFromNonReplacementFacetError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.CannotReplaceFunctionFromNonReplacementFacet.selector;
    }

    function _cannotRemoveFacetThatDoesNotExistError() internal pure override returns (bytes4) {
        return DiamondUpgradeFacet.CannotRemoveFacetThatDoesNotExist.selector;
    }
}
