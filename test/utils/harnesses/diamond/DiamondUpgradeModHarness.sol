// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import "src/diamond/DiamondUpgradeMod.sol" as DiamondUpgradeMod;

contract DiamondUpgradeModHarness {
    function upgradeDiamond(
        address[] calldata _addFacets,
        DiamondUpgradeMod.FacetReplacement[] calldata _replaceFacets,
        address[] calldata _removeFacets,
        address _delegate,
        bytes calldata _delegateCalldata,
        bytes32 _tag,
        bytes calldata _metadata
    ) external {
        DiamondUpgradeMod.upgradeDiamond(
            _addFacets, _replaceFacets, _removeFacets, _delegate, _delegateCalldata, _tag, _metadata
        );
    }
}
