// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626WithdrawFacet} from "src/token/ERC4626/Withdraw/ERC4626WithdrawFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626WithdrawFacet_Base_Test is ERC4626_Base_Test {
    ERC4626WithdrawFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626WithdrawFacet();
        vm.label(address(facet), "ERC4626WithdrawFacet");
        configureVault(address(facet));
    }
}
