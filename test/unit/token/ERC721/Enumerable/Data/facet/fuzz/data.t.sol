// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {
    ERC721EnumerableDataFacet_Base_Test
} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableDataFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";
import {ERC721EnumerableDataFacet} from "src/token/ERC721/Enumerable/Data/ERC721EnumerableDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Data_ERC721EnumerableDataFacet_Fuzz_Unit_Test is ERC721EnumerableDataFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldReturnTotalSupply_WhenAllTokensTracked(uint256 supply) external {
        supply = bound(supply, 0, 10);

        for (uint256 i; i < supply; i++) {
            address(facet).pushAllToken(i + 1);
        }

        uint256 result = facet.totalSupply();
        assertEq(result, supply, "totalSupply");
    }

    function testFuzz_ShouldRevert_TokenOfOwnerByIndex_WhenIndexOutOfBounds(
        address owner,
        uint256 balance,
        uint256 index
    ) external {
        vm.assume(owner != address(0));
        balance = bound(balance, 0, 10);
        index = bound(index, balance, type(uint256).max);

        /* Seed owner balance without ownerTokens to hit out-of-bounds branch */
        address(facet).setBalanceOf(owner, balance);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableDataFacet.ERC721OutOfBoundsIndex.selector, owner, index));
        facet.tokenOfOwnerByIndex(owner, index);
    }

    function testFuzz_ShouldReturnTokenOfOwnerByIndex_WhenIndexInBounds(address owner, uint256 balance) external {
        vm.assume(owner != address(0));
        balance = bound(balance, 1, 10);

        for (uint256 i; i < balance; i++) {
            uint256 tokenId = i + 1;
            address(facet).setOwnerTokenByIndex(owner, i, tokenId);
            address(facet).setOwnerTokensIndex(tokenId, i);
        }
        address(facet).setBalanceOf(owner, balance);

        for (uint256 i; i < balance; i++) {
            uint256 tokenId = facet.tokenOfOwnerByIndex(owner, i);
            assertEq(tokenId, i + 1, "tokenOfOwnerByIndex");
        }
    }

    function testFuzz_ShouldRevert_TokenByIndex_WhenIndexOutOfBounds(uint256 length, uint256 index) external {
        length = bound(length, 0, 10);
        index = bound(index, length, type(uint256).max);

        for (uint256 i; i < length; i++) {
            address(facet).pushAllToken(i + 1);
        }

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableDataFacet.ERC721OutOfBoundsIndex.selector, address(0), index)
        );
        facet.tokenByIndex(index);
    }

    function testFuzz_ShouldReturnTokenByIndex_WhenIndexInBounds(uint256 length) external {
        length = bound(length, 1, 10);

        for (uint256 i; i < length; i++) {
            address(facet).pushAllToken(i + 1);
        }

        for (uint256 i; i < length; i++) {
            uint256 tokenId = facet.tokenByIndex(i);
            assertEq(tokenId, i + 1, "tokenByIndex");
        }
    }
}

