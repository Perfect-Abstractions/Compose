// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721BurnMod_Base_Test} from "test/unit/token/ERC721/Burn/ERC721BurnModBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import "src/token/ERC721/Burn/ERC721BurnMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC721.tree
 */
contract Burn_ERC721BurnMod_Fuzz_Unit_Test is ERC721BurnMod_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_Burn_WhenTokenDoesNotExist(uint256 tokenId) external {
        tokenId = bound(tokenId, 1, type(uint128).max);

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        harness.burn(tokenId);
    }

    function testFuzz_ShouldBurn_WhenTokenExists(address owner, uint256 tokenId) external {
        vm.assume(owner != address(0));
        tokenId = bound(tokenId, 1, type(uint128).max);

        address(harness).mint(owner, tokenId);

        vm.expectEmit(address(harness));
        emit Transfer(owner, address(0), tokenId);
        harness.burn(tokenId);

        assertEq(address(harness).balanceOf(owner), 0, "owner balance");
    }
}

