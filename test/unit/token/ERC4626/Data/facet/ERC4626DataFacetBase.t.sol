// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626DataFacet} from "src/token/ERC4626/Data/ERC4626DataFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626DataFacet_Base_Test is ERC4626_Base_Test {
    ERC4626DataFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626DataFacet();
        vm.label(address(facet), "ERC4626DataFacet");
        configureVault(address(facet));
    }
}
