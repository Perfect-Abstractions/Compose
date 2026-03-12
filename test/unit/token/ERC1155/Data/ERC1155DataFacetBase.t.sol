// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155DataFacet} from "src/token/ERC1155/Data/ERC1155DataFacet.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";

abstract contract ERC1155DataFacet_Base_Test is Base_Test {
    using ERC1155StorageUtils for address;

    ERC1155DataFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC1155DataFacet();
        vm.label(address(facet), "ERC1155DataFacet");
    }

    function seedBalance(address target, uint256 id, address account, uint256 value) internal {
        target.setBalanceOf(id, account, value);
    }

    function seedApprovalForAll(address target, address account, address operator, bool value) internal {
        target.setApprovedForAll(account, operator, value);
    }
}
