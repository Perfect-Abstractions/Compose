// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721EnumerableBurnMod_Base_Test} from "test/unit/token/ERC721/Enumerable/ERC721EnumerableBurnModBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import "src/token/ERC721/Enumerable/Burn/ERC721EnumerableBurnMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Burn_ERC721EnumerableBurnMod_Fuzz_Unit_Test is ERC721EnumerableBurnMod_Base_Test {
    using ERC721StorageUtils for address;

    function _seedOwnerToken(address owner, uint256 tokenId) internal {
        uint256 ownerIndex = address(harness).balanceOf(owner);
        address(harness).setOwnerTokenByIndex(owner, ownerIndex, tokenId);
        address(harness).setOwnerTokensIndex(tokenId, ownerIndex);
        address(harness).setBalanceOf(owner, ownerIndex + 1);

        uint256 globalIndex = address(harness).allTokensLength();
        address(harness).pushAllToken(tokenId);
        address(harness).setAllTokensIndex(tokenId, globalIndex);
        address(harness).setOwnerOf(tokenId, owner);
    }

    function testFuzz_ShouldRevert_Burn_WhenTokenDoesNotExist(uint256 tokenId) external {
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        harness.burn(tokenId);
    }

    function testFuzz_ShouldBurnAndUpdateEnumeration_WhenTokenExists(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        _seedOwnerToken(owner, tokenId);

        vm.expectEmit(address(harness));
        emit Transfer(owner, address(0), tokenId);
        harness.burn(tokenId);

        assertEq(address(harness).balanceOf(owner), 0, "owner balance");
        assertEq(address(harness).allTokensLength(), 0, "allTokens length");
    }
}

