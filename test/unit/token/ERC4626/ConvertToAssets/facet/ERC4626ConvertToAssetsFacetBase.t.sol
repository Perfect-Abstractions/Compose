// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC4626ConvertToAssetsFacet} from "src/token/ERC4626/ConvertToAssets/ERC4626ConvertToAssetsFacet.sol";
import {ERC4626_Base_Test} from "test/unit/token/ERC4626/ERC4626Base.t.sol";

abstract contract ERC4626ConvertToAssetsFacet_Base_Test is ERC4626_Base_Test {
    ERC4626ConvertToAssetsFacet internal facet;

    function setUp() public virtual override {
        super.setUp();
        facet = new ERC4626ConvertToAssetsFacet();
        vm.label(address(facet), "ERC4626ConvertToAssetsFacet");
        configureVault(address(facet));
    }
}
