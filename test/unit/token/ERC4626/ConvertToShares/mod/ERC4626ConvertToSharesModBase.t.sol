// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";
import {
    ERC4626ConvertToSharesModHarness
} from "test/utils/harnesses/token/ERC4626/ERC4626ConvertToSharesModHarness.sol";

abstract contract ERC4626ConvertToSharesMod_Base_Test is ERC4626_Base_Test {
    ERC4626ConvertToSharesModHarness internal harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new ERC4626ConvertToSharesModHarness();
        vm.label(address(harness), "ERC4626ConvertToSharesModHarness");
        configureVault(address(harness));
    }
}
