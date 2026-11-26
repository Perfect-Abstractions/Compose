// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626RedeemModHarness} from "test/utils/harnesses/token/ERC4626/ERC4626RedeemModHarness.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626RedeemMod_Base_Test is ERC4626_Base_Test {
    ERC4626RedeemModHarness internal harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new ERC4626RedeemModHarness();
        vm.label(address(harness), "ERC4626RedeemModHarness");
        configureVault(address(harness));
    }
}
