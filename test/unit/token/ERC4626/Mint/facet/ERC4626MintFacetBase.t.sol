// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626MintFacet} from "src/token/ERC4626/Mint/ERC4626MintFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626MintFacet_Base_Test is ERC4626_Base_Test {
    ERC4626MintFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626MintFacet();
        vm.label(address(facet), "ERC4626MintFacet");
        configureVault(address(facet));
    }
}
