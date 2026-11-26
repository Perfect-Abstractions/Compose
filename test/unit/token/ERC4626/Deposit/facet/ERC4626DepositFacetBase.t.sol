// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DepositFacet} from "src/token/ERC4626/Deposit/ERC4626DepositFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626DepositFacet_Base_Test is ERC4626_Base_Test {
    ERC4626DepositFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626DepositFacet();
        vm.label(address(facet), "ERC4626DepositFacet");
        configureVault(address(facet));
    }
}
