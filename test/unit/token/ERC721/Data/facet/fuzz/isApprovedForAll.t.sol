// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721DataFacet_Base_Test} from "../ERC721DataFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {ERC721DataFacet} from "src/token/ERC721/Data/ERC721DataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract IsApprovedForAll_ERC721DataFacet_Fuzz_Unit_Test is ERC721DataFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_IsApprovedForAll(address owner, address operator, bool approved) external {
        address(facet).setApprovalForAll(owner, operator, approved);

        assertEq(facet.isApprovedForAll(owner, operator), approved, "isApprovedForAll(owner, operator)");
    }
}
