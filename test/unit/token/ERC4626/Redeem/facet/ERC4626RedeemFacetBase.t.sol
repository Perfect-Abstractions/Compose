// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626RedeemFacet} from "src/token/ERC4626/Redeem/ERC4626RedeemFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626RedeemFacet_Base_Test is ERC4626_Base_Test {
    ERC4626RedeemFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626RedeemFacet();
        vm.label(address(facet), "ERC4626RedeemFacet");
        configureVault(address(facet));
    }
}
