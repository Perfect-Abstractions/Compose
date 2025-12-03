// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import "../../../../src/token/ERC721/ERC721Enumerable/ERC721Enumerable.sol" as ERC721Enumerable;
import {ERC721EnumerableHarness} from "./harnesses/ERC721EnumerableHarness.sol";

contract LibERC721EnumerableTest is Test {
    ERC721EnumerableHarness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant BASE_URI = "https://example.com/api/nft/";

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new ERC721EnumerableHarness();
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

    function test_BaseURI() public view {
        assertEq(harness.baseURI(), BASE_URI);
    }

    /**
     * ============================================
     * Mint Tests
     * ============================================
     */

    function test_Mint() public {
        uint256 tokenId = 1;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, tokenId);
        harness.mint(alice, tokenId);

        assertEq(harness.ownerOf(tokenId), alice);
    }

    function test_MintUpdatesOwnership() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        assertEq(harness.ownerOf(tokenId), alice);
    }

    function test_MintUpdatesBalance() public {
        harness.mint(alice, 1);
        assertEq(harness.balanceOf(alice), 1);

        harness.mint(alice, 2);
        assertEq(harness.balanceOf(alice), 2);

        harness.mint(bob, 3);
        assertEq(harness.balanceOf(bob), 1);
    }

    function test_MintUpdatesOwnerTokens() public {
        harness.mint(alice, 10);
        harness.mint(alice, 20);
        harness.mint(alice, 30);

        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 10);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 20);
        assertEq(harness.tokenOfOwnerByIndex(alice, 2), 30);
    }

    function test_MintUpdatesAllTokens() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);
        harness.mint(charlie, 3);

        assertEq(harness.totalSupply(), 3);
        assertEq(harness.tokenByIndex(0), 1);
        assertEq(harness.tokenByIndex(1), 2);
        assertEq(harness.tokenByIndex(2), 3);
    }

    function test_MintUpdatesIndices() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);

        /**
         * Verify tokens are at correct indices
         */
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 2);
    }

    function test_MintMultipleTokens() public {
        for (uint256 i = 1; i <= 10; i++) {
            harness.mint(alice, i);
            assertEq(harness.ownerOf(i), alice);
        }

        assertEq(harness.balanceOf(alice), 10);
        assertEq(harness.totalSupply(), 10);
    }

    function test_MintToMultipleAddresses() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);
        harness.mint(charlie, 3);

        assertEq(harness.ownerOf(1), alice);
        assertEq(harness.ownerOf(2), bob);
        assertEq(harness.ownerOf(3), charlie);

        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.balanceOf(bob), 1);
        assertEq(harness.balanceOf(charlie), 1);
    }

    function test_MintEmitsTransferEvent() public {
        uint256 tokenId = 1;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, tokenId);
        harness.mint(alice, tokenId);
    }

    function test_MintRevertWhenZeroAddress() public {
        uint256 tokenId = 1;

        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721InvalidReceiver.selector, address(0)));
        harness.mint(address(0), tokenId);
    }

    function test_MintRevertWhenTokenExists() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721InvalidSender.selector, address(0)));
        harness.mint(bob, tokenId);
    }

    /**
     * ============================================
     * Transfer Tests
     * ============================================
     */

    function test_TransferFrom() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, tokenId);
        harness.transferFrom(alice, bob, tokenId);

        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_TransferFromByOwner() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);

        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_TransferFromByApproved() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.approve(bob, tokenId);

        vm.prank(bob);
        harness.transferFrom(alice, charlie, tokenId);

        assertEq(harness.ownerOf(tokenId), charlie);
    }

    function test_TransferFromByOperator() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        vm.prank(bob);
        harness.transferFrom(alice, charlie, tokenId);

        assertEq(harness.ownerOf(tokenId), charlie);
    }

    function test_TransferFromUpdatesOwnership() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);

        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_TransferFromUpdatesBalances() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);
        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.balanceOf(bob), 0);

        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);

        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.balanceOf(bob), 1);
    }

    function test_TransferFromUpdatesOwnerTokens() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        vm.prank(alice);
        harness.transferFrom(alice, bob, 2);

        /**
         * Alice should have tokens 1 and 3
         */
        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3);

        /**
         * Bob should have token 2
         */
        assertEq(harness.balanceOf(bob), 1);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 2);
    }

    function test_TransferFromUpdatesIndices() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        vm.prank(alice);
        harness.transferFrom(alice, bob, 1);

        /**
         * Verify indices are correct after transfer
         */
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 3);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 1);
    }

    function test_TransferFromClearsApproval() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.approve(bob, tokenId);

        assertEq(harness.getApproved(tokenId), bob);

        vm.prank(alice);
        harness.transferFrom(alice, charlie, tokenId);

        assertEq(harness.getApproved(tokenId), address(0));
    }

    function test_TransferFromEmitsTransferEvent() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, tokenId);
        harness.transferFrom(alice, bob, tokenId);
    }

    function test_TransferFromRevertWhenNonexistent() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721NonexistentToken.selector, tokenId));
        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);
    }

    function test_TransferFromRevertWhenZeroAddress() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721InvalidReceiver.selector, address(0)));
        vm.prank(alice);
        harness.transferFrom(alice, address(0), tokenId);
    }

    function test_TransferFromRevertWhenIncorrectOwner() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721IncorrectOwner.selector, bob, tokenId, alice));
        vm.prank(alice);
        harness.transferFrom(bob, charlie, tokenId);
    }

    function test_TransferFromRevertWhenUnauthorized() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721Enumerable.ERC721InsufficientApproval.selector, bob, tokenId));
        vm.prank(bob);
        harness.transferFrom(alice, charlie, tokenId);
    }

    /**
     * ============================================
     * Enumeration Tests
     * ============================================
     */

    function test_EnumerationAfterMultipleMints() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);
        harness.mint(alice, 3);
        harness.mint(charlie, 4);
        harness.mint(bob, 5);

        assertEq(harness.totalSupply(), 5);
        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 2);
        assertEq(harness.balanceOf(charlie), 1);

        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 1), 5);
        assertEq(harness.tokenOfOwnerByIndex(charlie, 0), 4);
    }

    function test_EnumerationAfterTransfers() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        vm.prank(alice);
        harness.transferFrom(alice, bob, 2);

        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);

        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 2);
    }

    function test_EnumerationComplexScenario() public {
        /**
         * Mint tokens
         */
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(bob, 3);
        harness.mint(charlie, 4);

        assertEq(harness.totalSupply(), 4);

        /**
         * Transfer token
         */
        vm.prank(alice);
        harness.transferFrom(alice, bob, 1);

        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.balanceOf(bob), 2);

        /**
         * Verify final state
         */
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 3);
        assertEq(harness.tokenOfOwnerByIndex(bob, 1), 1);
        assertEq(harness.tokenOfOwnerByIndex(charlie, 0), 4);
    }

    /**
     * ============================================
     * Fuzz Tests
     * ============================================
     */

    function test_MintFuzz(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(to, tokenId);

        assertEq(harness.ownerOf(tokenId), to);
        assertEq(harness.balanceOf(to), 1);
        assertEq(harness.totalSupply(), 1);
    }

    function test_TransferFromFuzz(address from, address to, uint256 tokenId) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(from, tokenId);

        vm.prank(from);
        harness.transferFrom(from, to, tokenId);

        assertEq(harness.ownerOf(tokenId), to);
    }
}
