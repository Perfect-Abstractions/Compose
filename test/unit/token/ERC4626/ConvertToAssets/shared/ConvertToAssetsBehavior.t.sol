// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

/**
 * @dev BTT spec: test/trees/ERC4626.tree
 */
abstract contract ConvertToAssetsBehavior is ERC4626_Base_Test {
    function vault() internal view virtual returns (address);

    function convert(uint256 amount) internal view virtual returns (uint256);

    function test_ShouldReturnZero_WhenShareAmountIsZero() external {
        seedVault(vault(), 13, 11);

        assertEq(convert(0), 0, "zero input");
    }

    function test_ShouldUseVirtualOffsets_WhenVaultIsEmpty() external view {
        assertEq(convert(29), 2, "empty vault quote");
    }

    function testFuzz_ShouldRoundDown_WhenVaultHasAssetsAndShares(uint128 amount, uint128 vaultAssets, uint128 shares)
        external
    {
        uint256 actualAssets = bound(vaultAssets, 1, type(uint128).max - 1);
        uint256 totalShares = bound(shares, 1, type(uint128).max - 10);
        seedVault(vault(), actualAssets, totalShares);

        uint256 expected = uint256(amount) * (actualAssets + 1) / (totalShares + 10);
        assertEq(convert(amount), expected, "rounded-down quote");
    }

    function test_ShouldPreserveFullPrecision_WhenIntermediateProductOverflows() external {
        uint256 scale = 1 << 128;
        seedVault(vault(), scale - 1, scale - 8);

        assertEq(convert(scale + 1), scale - 1, "full-precision rounded-down quote");
    }
}
