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
contract BalanceOf_ERC721DataFacet_Fuzz_Unit_Test is ERC721DataFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_OwnerIsZeroAddress() external {
        vm.expectRevert(abi.encodeWithSelector(ERC721DataFacet.ERC721InvalidOwner.selector, ADDRESS_ZERO));
        facet.balanceOf(ADDRESS_ZERO);
    }

    function testFuzz_BalanceOf(address owner, uint256 balance) external whenOwnerNotZeroAddress {
        vm.assume(owner != ADDRESS_ZERO);
        balance = bound(balance, 0, MAX_UINT256);

        address(facet).setBalanceOf(owner, balance);

        assertEq(facet.balanceOf(owner), balance, "balanceOf(owner)");
    }
}
