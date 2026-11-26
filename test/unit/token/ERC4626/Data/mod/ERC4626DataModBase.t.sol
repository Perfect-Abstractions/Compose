// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";
import {ERC4626DataModHarness} from "test/utils/harnesses/token/ERC4626/ERC4626DataModHarness.sol";

abstract contract ERC4626DataMod_Base_Test is ERC4626_Base_Test {
    ERC4626DataModHarness internal harness;

    function setUp() public virtual override {
        super.setUp();
        harness = new ERC4626DataModHarness();
        vm.label(address(harness), "ERC4626DataModHarness");
        configureVault(address(harness));
    }
}
