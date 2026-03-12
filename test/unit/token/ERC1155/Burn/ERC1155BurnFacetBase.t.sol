// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC1155BurnFacet} from "src/token/ERC1155/Burn/ERC1155BurnFacet.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";

abstract contract ERC1155BurnFacet_Base_Test is Base_Test {
    using ERC1155StorageUtils for address;

    ERC1155BurnFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC1155BurnFacet();
        vm.label(address(facet), "ERC1155BurnFacet");
    }

    function seedBalance(address target, uint256 id, address account, uint256 value) internal {
        target.setBalanceOf(id, account, value);
    }

    function seedApprovalForAll(address target, address account, address operator, bool value) internal {
        target.setApprovedForAll(account, operator, value);
    }
}
