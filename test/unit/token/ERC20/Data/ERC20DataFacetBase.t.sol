// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20DataFacet} from "src/token/ERC20/Data/ERC20DataFacet.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

abstract contract ERC20DataFacet_Base_Test is Base_Test {
    using ERC20StorageUtils for address;

    ERC20DataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20DataFacet();
        vm.label(address(facet), "ERC20DataFacet");
    }
}
