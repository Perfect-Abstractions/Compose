// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909TransferFacet} from "src/token/ERC6909/Transfer/ERC6909TransferFacet.sol";

import {ERC6909_Test_Base} from "test/unit/token/ERC6909/ERC6909TestBase.sol";

abstract contract ERC6909TransferFacet_Base_Test is ERC6909_Test_Base {
    ERC6909TransferFacet internal facet;

    function setUp() public virtual override {
        ERC6909_Test_Base.setUp();
        facet = new ERC6909TransferFacet();
        vm.label(address(facet), "ERC6909TransferFacet");
    }
}
