// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC721Harness} from "./harnesses/LibERC721Harness.sol";
import * as LibERC721 from "../../../../src/token/ERC721/ERC721/LibERC721.sol";

contract LibERC721Test is Test {
    LibERC721Harness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant BASE_URI = "https://example.com/api/nft/";

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new LibERC721Harness();
        harness.initialize(TOKEN_NAME, TOKEN_SYMBOL, BASE_URI);
    }

    /**
     * ============================================
     * Metadata Tests
     * ============================================
     */

    function test_Name() public view {
        assertEq(harness.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(harness.symbol(), TOKEN_SYMBOL);
    }

    function test_baseURI() public view {
        assertEq(harness.baseURI(), BASE_URI);
    }

    /**
     * ============================================
     * TransferFrom Tests
     * ============================================
     */

    function test_TransferFrom() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);
        assertEq(harness.ownerOf(tokenId), alice);

        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);
        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_TransferToSelf() public {
        uint256 tokenId = 2;

        harness.mint(charlie, tokenId);
        assertEq(harness.ownerOf(tokenId), charlie);

        vm.prank(charlie);
        harness.transferFrom(charlie, charlie, tokenId);
        assertEq(harness.ownerOf(tokenId), charlie);
    }

    function test_TransferFuzz(address from, address to, uint256 tokenId) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(from, tokenId);
        assertEq(harness.ownerOf(tokenId), from);

        vm.prank(from);
        harness.transferFrom(from, to, tokenId);
        assertEq(harness.ownerOf(tokenId), to);
    }

    function test_TransferRevertWhenTransferFromNonExistentToken() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721NonexistentToken.selector, tokenId));
        harness.transferFrom(alice, bob, tokenId);
    }

    function test_TransferRevertWhenSenderIsNotOwnerOrApproved() public {
        uint256 tokenId = 4;

        harness.mint(alice, tokenId);
        assertEq(harness.ownerOf(tokenId), alice);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InsufficientApproval.selector, bob, tokenId));
        harness.transferFrom(alice, charlie, tokenId);
    }

    /**
     * ============================================
     * Mint Tests
     * ============================================
     */

    function test_Mint() public {
        uint256 tokenId = 5;

        harness.mint(bob, tokenId);
        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_MintMultiple() public {
        for (uint256 tokenId = 1; tokenId <= 10; tokenId++) {
            harness.mint(charlie, tokenId);
            assertEq(harness.ownerOf(tokenId), charlie);
        }
    }

    function test_MintFuzz(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(to, tokenId);
        assertEq(harness.ownerOf(tokenId), to);
    }

    function test_MintRevertWhenInvalidReceiver() public {
        uint256 tokenId = 6;

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InvalidReceiver.selector, address(0)));
        harness.mint(address(0), tokenId);
    }

    /**
     * ============================================
     * Burn Tests
     * ============================================
     */

    function test_Burn() public {
        uint256 tokenId = 7;

        harness.mint(alice, tokenId);
        assertEq(harness.ownerOf(tokenId), alice);

        harness.burn(tokenId);
        assertEq(harness.ownerOf(tokenId), address(0));
    }

    function test_BurnFuzz(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(to, tokenId);
        assertEq(harness.ownerOf(tokenId), to);

        harness.burn(tokenId);
        assertEq(harness.ownerOf(tokenId), address(0));
    }

    function test_BurnRevertWhenNonExistentToken() public {
        uint256 tokenId = 888;

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721NonexistentToken.selector, tokenId));
        harness.burn(tokenId);
    }
}
