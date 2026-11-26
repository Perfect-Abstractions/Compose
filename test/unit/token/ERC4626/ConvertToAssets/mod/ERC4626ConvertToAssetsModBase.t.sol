// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";
import {
    ERC4626ConvertToAssetsModHarness
} from "test/utils/harnesses/token/ERC4626/ERC4626ConvertToAssetsModHarness.sol";

abstract contract ERC4626ConvertToAssetsMod_Base_Test is ERC4626_Base_Test {
    ERC4626ConvertToAssetsModHarness internal harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new ERC4626ConvertToAssetsModHarness();
        vm.label(address(harness), "ERC4626ConvertToAssetsModHarness");
        configureVault(address(harness));
    }
}
