// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626WithdrawModHarness} from "test/utils/harnesses/token/ERC4626/ERC4626WithdrawModHarness.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626WithdrawMod_Base_Test is ERC4626_Base_Test {
    ERC4626WithdrawModHarness internal harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new ERC4626WithdrawModHarness();
        vm.label(address(harness), "ERC4626WithdrawModHarness");
        configureVault(address(harness));
    }
}
