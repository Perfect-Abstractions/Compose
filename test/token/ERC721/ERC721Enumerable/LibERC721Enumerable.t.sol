// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC721EnumerableHarness} from "./harnesses/LibERC721EnumerableHarness.sol";
import {LibERC721} from "../../../../src/token/ERC721/ERC721Enumerable/LibERC721Enumerable.sol";

contract LibERC721EnumerableTest is Test {
    LibERC721EnumerableHarness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test NFT";
    string constant TOKEN_SYMBOL = "TNFT";
    string constant BASE_URI = "https://example.com/token/";

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new LibERC721EnumerableHarness();
        harness.initialize(TOKEN_NAME, TOKEN_SYMBOL, BASE_URI);
    }

    // ============================================
    // Metadata Tests
    // ============================================

    function test_Name() public view {
        assertEq(harness.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(harness.symbol(), TOKEN_SYMBOL);
    }

    function test_BaseURI() public view {
        assertEq(harness.baseURI(), BASE_URI);
    }

    function test_InitialTotalSupply() public view {
        assertEq(harness.totalSupply(), 0);
    }

    // ============================================
    // Mint Tests - CORE BUG FIX VALIDATION
    // ============================================

    function test_Mint_SetsOwner() public {
        uint256 tokenId = 1;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, tokenId);
        harness.mint(alice, tokenId);

        // CRITICAL: This is the bug we're fixing - ownerOf must be set
        assertEq(harness.ownerOf(tokenId), alice, "Owner not set correctly");
        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.totalSupply(), 1);
    }

    function test_Mint_Multiple_SetsOwnersCorrectly() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);
        harness.mint(alice, 3);

        // Verify each token has correct owner
        assertEq(harness.ownerOf(1), alice, "Token 1 owner incorrect");
        assertEq(harness.ownerOf(2), bob, "Token 2 owner incorrect");
        assertEq(harness.ownerOf(3), alice, "Token 3 owner incorrect");

        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);
        assertEq(harness.totalSupply(), 3);
    }

    function test_Mint_UpdatesOwnedTokens() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(bob, 3);

        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 3);
    }

    function test_Mint_UpdatesAllTokens() public {
        harness.mint(alice, 10);
        harness.mint(bob, 20);
        harness.mint(charlie, 30);

        assertEq(harness.totalSupply(), 3);
        assertEq(harness.tokenByIndex(0), 10);
        assertEq(harness.tokenByIndex(1), 20);
        assertEq(harness.tokenByIndex(2), 30);
    }

    function test_Mint_UpdatesIndices() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);

        assertEq(harness.ownedTokensIndexOf(1), 0);
        assertEq(harness.ownedTokensIndexOf(2), 1);
        assertEq(harness.allTokensIndexOf(1), 0);
        assertEq(harness.allTokensIndexOf(2), 1);
    }

    function testFuzz_Mint_SetsOwner(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId > 0 && tokenId < type(uint256).max);

        harness.mint(to, tokenId);

        // The critical assertion - owner must be set
        assertEq(harness.ownerOf(tokenId), to);
        assertEq(harness.balanceOf(to), 1);
        assertEq(harness.totalSupply(), 1);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InvalidReceiver.selector, address(0)));
        harness.mint(address(0), 1);
    }

    function test_RevertWhen_MintExistingToken() public {
        harness.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InvalidSender.selector, address(0)));
        harness.mint(bob, 1);
    }

    // ============================================
    // Burn Tests
    // ============================================

    function test_Burn() public {
        harness.mint(alice, 1);
        assertEq(harness.ownerOf(1), alice);

        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), 1);
        harness.burn(1, alice);

        assertEq(harness.ownerOf(1), address(0));
        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.totalSupply(), 0);
    }

    function test_Burn_RemovesFromOwnedTokens() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        assertEq(harness.balanceOf(alice), 3);

        harness.burn(2, alice);

        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3); // Last token moved to index 1
    }

    function test_Burn_RemovesFromAllTokens() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);
        harness.mint(charlie, 3);

        assertEq(harness.totalSupply(), 3);

        harness.burn(2, bob);

        assertEq(harness.totalSupply(), 2);
        assertEq(harness.tokenByIndex(0), 1);
        assertEq(harness.tokenByIndex(1), 3); // Last token moved to index 1
    }

    function test_Burn_LastToken() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);

        harness.burn(2, alice);

        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.totalSupply(), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
    }

    function test_RevertWhen_BurnNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721NonexistentToken.selector, 1));
        harness.burn(1, alice);
    }

    function test_RevertWhen_BurnUnauthorized() public {
        harness.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InsufficientApproval.selector, bob, 1));
        harness.burn(1, bob);
    }

    // ============================================
    // Transfer Tests
    // ============================================

    function test_TransferFrom() public {
        harness.mint(alice, 1);

        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        harness.transferFrom(alice, bob, 1, alice);

        assertEq(harness.ownerOf(1), bob);
        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.balanceOf(bob), 1);
    }

    function test_TransferFrom_UpdatesOwnedTokens() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        harness.transferFrom(alice, bob, 2, alice);

        // Alice should have tokens 1 and 3
        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3);

        // Bob should have token 2
        assertEq(harness.balanceOf(bob), 1);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 2);
    }

    function test_TransferFrom_DoesNotAffectAllTokens() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);

        harness.transferFrom(alice, charlie, 1, alice);

        // Total supply and allTokens should remain the same
        assertEq(harness.totalSupply(), 2);
        assertEq(harness.tokenByIndex(0), 1);
        assertEq(harness.tokenByIndex(1), 2);
    }

    function test_TransferFrom_MultipleTransfers() public {
        harness.mint(alice, 1);

        harness.transferFrom(alice, bob, 1, alice);
        assertEq(harness.ownerOf(1), bob);

        harness.transferFrom(bob, charlie, 1, bob);
        assertEq(harness.ownerOf(1), charlie);

        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.balanceOf(bob), 0);
        assertEq(harness.balanceOf(charlie), 1);
    }

    function testFuzz_TransferFrom(address from, address to, uint256 tokenId) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(tokenId > 0);

        harness.mint(from, tokenId);

        harness.transferFrom(from, to, tokenId, from);

        assertEq(harness.ownerOf(tokenId), to);
        assertEq(harness.balanceOf(from), 0);
        assertEq(harness.balanceOf(to), 1);
    }

    function test_RevertWhen_TransferFromNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721NonexistentToken.selector, 999));
        harness.transferFrom(alice, bob, 999, alice);
    }

    function test_RevertWhen_TransferFromIncorrectOwner() public {
        harness.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721IncorrectOwner.selector, bob, 1, alice));
        harness.transferFrom(bob, charlie, 1, bob);
    }

    function test_RevertWhen_TransferFromToZeroAddress() public {
        harness.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InvalidReceiver.selector, address(0)));
        harness.transferFrom(alice, address(0), 1, alice);
    }

    function test_RevertWhen_TransferFromUnauthorized() public {
        harness.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721InsufficientApproval.selector, bob, 1));
        harness.transferFrom(alice, charlie, 1, bob);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintTransferBurn_Flow() public {
        // Mint multiple tokens
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(bob, 3);

        assertEq(harness.totalSupply(), 3);
        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);

        // Transfer
        harness.transferFrom(alice, charlie, 1, alice);

        assertEq(harness.ownerOf(1), charlie);
        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.balanceOf(charlie), 1);

        // Burn
        harness.burn(2, alice);

        assertEq(harness.totalSupply(), 2);
        assertEq(harness.balanceOf(alice), 0);

        // Final state
        assertEq(harness.ownerOf(1), charlie);
        assertEq(harness.ownerOf(3), bob);
        assertEq(harness.totalSupply(), 2);
    }

    function test_ComplexEnumeration_Flow() public {
        // Mint tokens to multiple addresses
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);
        harness.mint(bob, 4);
        harness.mint(bob, 5);

        // Verify enumeration
        assertEq(harness.totalSupply(), 5);
        assertEq(harness.balanceOf(alice), 3);
        assertEq(harness.balanceOf(bob), 2);

        // Transfer one from alice to bob
        harness.transferFrom(alice, bob, 2, alice);

        // Verify updated enumeration
        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 3);

        // Burn from middle of bob's collection
        harness.burn(4, bob);

        // Verify final state
        assertEq(harness.totalSupply(), 4);
        assertEq(harness.balanceOf(bob), 2);

        // Verify owned tokens (order may have changed due to swap-and-pop)
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 1), 5);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_Mint_MaxUint256TokenId() public {
        uint256 maxTokenId = type(uint256).max;
        harness.mint(alice, maxTokenId);

        assertEq(harness.ownerOf(maxTokenId), alice);
        assertEq(harness.balanceOf(alice), 1);
    }

    function test_Burn_OnlyTokenOwned() public {
        harness.mint(alice, 1);
        harness.burn(1, alice);

        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.totalSupply(), 0);
    }

    function test_Transfer_LastTokenInCollection() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        // Transfer the last token
        harness.transferFrom(alice, bob, 3, alice);

        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 3);
    }
}

