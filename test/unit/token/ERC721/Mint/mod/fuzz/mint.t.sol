// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721MintMod_Base_Test} from "test/unit/token/ERC721/Mint/ERC721MintModBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import "src/token/ERC721/Mint/ERC721MintMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Mint_ERC721MintMod_Fuzz_Unit_Test is ERC721MintMod_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_Mint_WhenToIsZeroAddress(uint256 tokenId) external {
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(0)));
        harness.mint(address(0), tokenId);
    }

    function testFuzz_ShouldRevert_Mint_WhenTokenAlreadyExists(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(harness).mint(owner, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidSender.selector, address(0)));
        harness.mint(owner, tokenId);
    }

    function testFuzz_ShouldMint_WhenValidInputs(address to, uint256 tokenId) external {
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectEmit(address(harness));
        emit Transfer(address(0), to, tokenId);
        harness.mint(to, tokenId);

        assertEq(address(harness).ownerOf(tokenId), to, "ownerOf");
        assertEq(address(harness).balanceOf(to), 1, "balanceOf(to)");
    }
}

