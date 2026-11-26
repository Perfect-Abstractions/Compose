// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DepositModHarness} from "test/utils/harnesses/token/ERC4626/ERC4626DepositModHarness.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626DepositMod_Base_Test is ERC4626_Base_Test {
    ERC4626DepositModHarness internal harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new ERC4626DepositModHarness();
        vm.label(address(harness), "ERC4626DepositModHarness");
        configureVault(address(harness));
    }
}
