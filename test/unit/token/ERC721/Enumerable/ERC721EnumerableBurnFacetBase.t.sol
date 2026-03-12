// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC721EnumerableBurnFacet} from "src/token/ERC721/Enumerable/Burn/ERC721EnumerableBurnFacet.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

abstract contract ERC721EnumerableBurnFacet_Base_Test is Base_Test {
    using ERC721StorageUtils for address;

    ERC721EnumerableBurnFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC721EnumerableBurnFacet();
        vm.label(address(facet), "ERC721EnumerableBurnFacet");
    }
}

