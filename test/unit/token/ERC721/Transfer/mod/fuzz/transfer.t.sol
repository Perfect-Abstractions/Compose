// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721TransferMod_Base_Test} from "test/unit/token/ERC721/Transfer/ERC721TransferModBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import "src/token/ERC721/Transfer/ERC721TransferMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Transfer_ERC721TransferMod_Fuzz_Unit_Test is ERC721TransferMod_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_TransferFrom_WhenTokenDoesNotExist(address from, address to, uint256 tokenId)
        external
    {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        harness.transferFrom(from, to, tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenToIsZeroAddress(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(harness).mint(owner, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721InvalidReceiver.selector, address(0)));
        harness.transferFrom(owner, address(0), tokenId);
    }

    function testFuzz_ShouldRevert_TransferFrom_WhenFromIsNotOwner(
        address owner,
        address wrongFrom,
        address to,
        uint256 tokenId
    ) external {
        vm.assume(owner != address(0));
        vm.assume(wrongFrom != address(0));
        vm.assume(wrongFrom != owner);
        vm.assume(to != address(0));
        vm.assume(to != owner);
        vm.assume(to != wrongFrom);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(harness).mint(owner, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721IncorrectOwner.selector, wrongFrom, tokenId, owner));
        harness.transferFrom(wrongFrom, to, tokenId);
    }

    function testFuzz_ShouldTransfer_WhenCalledWithCorrectOwner(address owner, address to, uint256 tokenId) external {
        vm.assume(owner != address(0));
        vm.assume(to != address(0));
        vm.assume(to != owner);
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(harness).mint(owner, tokenId);

        vm.expectEmit(address(harness));
        emit Transfer(owner, to, tokenId);
        harness.transferFrom(owner, to, tokenId);

        assertEq(address(harness).ownerOf(tokenId), to, "new owner");
        assertEq(address(harness).balanceOf(owner), 0, "owner balance");
        assertEq(address(harness).balanceOf(to), 1, "receiver balance");
    }
}

