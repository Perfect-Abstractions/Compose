// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToAssetsFacet_Base_Test} from "../ERC4626ConvertToAssetsFacetBase.t.sol";
import {ConvertToAssetsBehavior} from "../../shared/ConvertToAssetsBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

contract ConvertToAssets_ERC4626ConvertToAssetsFacet_Fuzz_Unit_Test is
    ERC4626ConvertToAssetsFacet_Base_Test,
    ConvertToAssetsBehavior
{
    function setUp() public override(ERC4626ConvertToAssetsFacet_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(facet);
    }

    function convert(uint256 amount) internal view override returns (uint256) {
        return facet.convertToAssets(amount);
    }
}
