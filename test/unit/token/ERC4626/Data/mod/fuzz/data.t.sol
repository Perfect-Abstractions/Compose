// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DataMod_Base_Test} from "../ERC4626DataModBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
contract Data_ERC4626DataMod_Fuzz_Unit_Test is ERC4626DataMod_Base_Test {
    using ERC20StorageUtils for address;

    function test_ShouldReturnConfiguredAsset_WhenQueried() external view {
        assertEq(harness.asset(), address(assetToken), "asset");
    }

    function test_ShouldReturnZeroTotalAssets_WhenVaultIsEmpty() external view {
        assertEq(harness.totalAssets(), 0, "empty vault asset balance");
    }

    function testFuzz_ShouldReturnActualVaultBalance_WhenVaultHoldsAssets(uint256 vaultAssets, uint256 otherAssets)
        external
    {
        vaultAssets = bound(vaultAssets, 1, type(uint256).max);
        address(assetToken).setBalance(address(harness), vaultAssets);
        address(assetToken).setBalance(users.bob, otherAssets);

        assertEq(harness.totalAssets(), vaultAssets, "actual vault balance");
    }
}
