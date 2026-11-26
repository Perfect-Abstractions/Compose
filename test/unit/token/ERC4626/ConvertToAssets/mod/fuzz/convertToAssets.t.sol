// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToAssetsMod_Base_Test} from "../ERC4626ConvertToAssetsModBase.t.sol";
import {ConvertToAssetsBehavior} from "../../shared/ConvertToAssetsBehavior.t.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

contract ConvertToAssets_ERC4626ConvertToAssetsMod_Fuzz_Unit_Test is
    ERC4626ConvertToAssetsMod_Base_Test,
    ConvertToAssetsBehavior
{
    function setUp() public override(ERC4626ConvertToAssetsMod_Base_Test, ERC4626_Base_Test) {
        super.setUp();
    }

    function vault() internal view override returns (address) {
        return address(harness);
    }

    function convert(uint256 amount) internal view override returns (uint256) {
        return harness.convertToAssets(amount);
    }
}
