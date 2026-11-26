// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToSharesFacet} from "src/token/ERC4626/ConvertToShares/ERC4626ConvertToSharesFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626ConvertToSharesFacet_Base_Test is ERC4626_Base_Test {
    ERC4626ConvertToSharesFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626ConvertToSharesFacet();
        vm.label(address(facet), "ERC4626ConvertToSharesFacet");
        configureVault(address(facet));
    }
}
