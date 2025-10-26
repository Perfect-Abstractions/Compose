// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721EnumerableFacet} from "../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableFacet.sol";
import {ERC721EnumerableFacetHarness} from "./harnesses/ERC721EnumerableFacetHarness.sol";

contract ERC721EnumerableFacetTest is Test {
    ERC721EnumerableFacetHarness public token;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test NFT";
    string constant TOKEN_SYMBOL = "TNFT";
    string constant TOKEN_BASE_URI = "https://api.example.com/metadata/";

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new ERC721EnumerableFacetHarness();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_BASE_URI);
    }

    // ============================================
    // Metadata Tests
    // ============================================

    function test_Name() public view {
        assertEq(token.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    function test_TokenURI() public {
        token.mint(alice, 1);
        assertEq(token.tokenURI(1), string.concat(TOKEN_BASE_URI, "1"));
    }

    function test_TokenURI_EmptyBaseURI() public {
        ERC721EnumerableFacetHarness emptyToken = new ERC721EnumerableFacetHarness();
        emptyToken.initialize("Empty", "EMPTY", "");
        emptyToken.mint(alice, 1);
        assertEq(emptyToken.tokenURI(1), "");
    }

    // ============================================
    // Enumeration Tests
    // ============================================

    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_TotalSupply_AfterMint() public {
        token.mint(alice, 1);
        assertEq(token.totalSupply(), 1);
    }

    function test_TotalSupply_AfterBurn() public {
        token.mint(alice, 1);
        vm.prank(alice);
        token.burn(1);
        assertEq(token.totalSupply(), 0);
    }

    function test_TokenOfOwnerByIndex() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(bob, 3);

        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 3);
    }

    function test_TokenOfOwnerByIndex_AfterTransfer() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(alice, 3);

        vm.prank(alice);
        token.transferFrom(alice, bob, 2);

        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 2);
    }

    function test_TokenOfOwnerByIndex_AfterBurn() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(alice, 3);

        vm.prank(alice);
        token.burn(2);

        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 3);
    }

    function test_Fuzz_TokenOfOwnerByIndex(uint256 numTokens) public {
        vm.assume(numTokens > 0 && numTokens < 100);

        for (uint256 i = 1; i <= numTokens; i++) {
            token.mint(alice, i);
        }

        assertEq(token.balanceOf(alice), numTokens);
        assertEq(token.totalSupply(), numTokens);

        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(token.tokenOfOwnerByIndex(alice, i), i + 1);
        }
    }

    function test_RevertWhen_TokenOfOwnerByIndexOutOfBounds() public {
        token.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721OutOfBoundsIndex.selector, alice, 1));
        token.tokenOfOwnerByIndex(alice, 1);
    }

    // ============================================
    // Mint Tests
    // ============================================

    function test_Mint() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, 1);
        token.mint(alice, 1);

        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.totalSupply(), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
    }

    function test_Mint_Multiple() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(bob, 3);

        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.totalSupply(), 3);
        assertEq(token.ownerOf(1), alice);
        assertEq(token.ownerOf(2), alice);
        assertEq(token.ownerOf(3), bob);
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 3);
    }

    function test_Fuzz_Mint(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId > 0);

        token.mint(to, tokenId);

        assertEq(token.ownerOf(tokenId), to);
        assertEq(token.balanceOf(to), 1);
        assertEq(token.totalSupply(), 1);
        assertEq(token.tokenOfOwnerByIndex(to, 0), tokenId);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidReceiver.selector, address(0)));
        token.mint(address(0), 1);
    }

    function test_RevertWhen_MintExistingToken() public {
        token.mint(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidSender.selector, address(0)));
        token.mint(bob, 1);
    }

    // ============================================
    // Burn Tests
    // ============================================

    function test_Burn() public {
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), 1);
        token.burn(1);

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(alice), 0);

        vm.expectRevert();
        token.ownerOf(1);
    }

    function test_Burn_EntireBalance() public {
        token.mint(alice, 1);
        token.mint(alice, 2);

        vm.startPrank(alice);
        token.burn(1);
        token.burn(2);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    function test_Burn_UpdatesIndices() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(alice, 3);

        vm.prank(alice);
        token.burn(2);

        assertEq(token.balanceOf(alice), 2);
        assertEq(token.totalSupply(), 2);
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 3);
    }

    function test_Fuzz_Burn(uint256 tokenId) public {
        vm.assume(tokenId > 0);

        token.mint(alice, tokenId);

        vm.prank(alice);
        token.burn(tokenId);

        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(alice), 0);

        vm.expectRevert();
        token.ownerOf(tokenId);
    }

    function test_RevertWhen_BurnNonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.burn(1);
    }

    // ============================================
    // Transfer Tests
    // ============================================

    function test_TransferFrom() public {
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        token.transferFrom(alice, bob, 1);

        assertEq(token.ownerOf(1), bob);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 1);
    }

    function test_TransferFrom_UpdatesIndices() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(alice, 3);

        vm.prank(alice);
        token.transferFrom(alice, bob, 2);

        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 2);
    }

    function test_TransferFrom_ToSelf() public {
        token.mint(alice, 1);

        vm.prank(alice);
        token.transferFrom(alice, alice, 1);

        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
    }

    function test_Fuzz_TransferFrom(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId > 0);

        token.mint(alice, tokenId);

        vm.prank(alice);
        token.transferFrom(alice, to, tokenId);

        assertEq(token.ownerOf(tokenId), to);
        assertEq(token.tokenOfOwnerByIndex(to, 0), tokenId);
    }

    function test_RevertWhen_TransferFromZeroAddressSender() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.transferFrom(address(0), bob, 1);
    }

    function test_RevertWhen_TransferFromZeroAddressReceiver() public {
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidReceiver.selector, address(0)));
        token.transferFrom(alice, address(0), 1);
    }

    function test_RevertWhen_TransferFromNonExistentToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.transferFrom(alice, bob, 1);
    }

    function test_RevertWhen_TransferFromIncorrectOwner() public {
        token.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InsufficientApproval.selector, bob, 1));
        token.transferFrom(alice, charlie, 1);
    }

    function test_RevertWhen_TransferFromInsufficientApproval() public {
        token.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InsufficientApproval.selector, bob, 1));
        token.transferFrom(alice, charlie, 1);
    }

    // ============================================
    // Safe Transfer Tests
    // ============================================

    function test_SafeTransferFrom() public {
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        token.safeTransferFrom(alice, bob, 1);

        assertEq(token.ownerOf(1), bob);
    }

    function test_SafeTransferFromWithData() public {
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        token.safeTransferFrom(alice, bob, 1, "0x1234");

        assertEq(token.ownerOf(1), bob);
    }

    // ============================================
    // Approval Tests
    // ============================================

    function test_Approve() public {
        token.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 1);
        token.approve(bob, 1);

        assertEq(token.getApproved(1), bob);
    }

    function test_Approve_UpdateExisting() public {
        token.mint(alice, 1);

        vm.startPrank(alice);
        token.approve(bob, 1);
        token.approve(charlie, 1);
        vm.stopPrank();

        assertEq(token.getApproved(1), charlie);
    }

    function test_Approve_ZeroAddress() public {
        token.mint(alice, 1);

        vm.prank(alice);
        token.approve(address(0), 1);

        assertEq(token.getApproved(1), address(0));
    }

    function test_Fuzz_Approve(address approved, uint256 tokenId) public {
        vm.assume(tokenId > 0);

        token.mint(alice, tokenId);

        vm.prank(alice);
        token.approve(approved, tokenId);

        assertEq(token.getApproved(tokenId), approved);
    }

    function test_RevertWhen_ApproveNonExistentToken() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.approve(bob, 1);
    }

    function test_RevertWhen_ApproveIncorrectOwner() public {
        token.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidApprover.selector, bob));
        token.approve(charlie, 1);
    }

    // ============================================
    // SetApprovalForAll Tests
    // ============================================

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, bob, true);
        token.setApprovalForAll(bob, true);

        assertTrue(token.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAll_Revoke() public {
        vm.startPrank(alice);
        token.setApprovalForAll(bob, true);
        token.setApprovalForAll(bob, false);
        vm.stopPrank();

        assertFalse(token.isApprovedForAll(alice, bob));
    }

    function test_Fuzz_SetApprovalForAll(address operator, bool approved) public {
        vm.assume(operator != address(0));

        vm.prank(alice);
        token.setApprovalForAll(operator, approved);

        assertEq(token.isApprovedForAll(alice, operator), approved);
    }

    function test_RevertWhen_SetApprovalForAllZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidOperator.selector, address(0)));
        token.setApprovalForAll(address(0), true);
    }

    // ============================================
    // Operator Transfer Tests
    // ============================================

    function test_OperatorCanTransfer() public {
        token.mint(alice, 1);

        vm.prank(alice);
        token.setApprovalForAll(bob, true);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, charlie, 1);
        token.transferFrom(alice, charlie, 1);

        assertEq(token.ownerOf(1), charlie);
    }

    function test_ApprovedCanTransfer() public {
        token.mint(alice, 1);

        vm.prank(alice);
        token.approve(bob, 1);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, charlie, 1);
        token.transferFrom(alice, charlie, 1);

        assertEq(token.ownerOf(1), charlie);
    }

    function test_ApprovalClearedOnTransfer() public {
        token.mint(alice, 1);

        vm.prank(alice);
        token.approve(bob, 1);
        assertEq(token.getApproved(1), bob);

        vm.prank(alice);
        token.transferFrom(alice, charlie, 1);
        assertEq(token.getApproved(1), address(0));
    }

    // ============================================
    // Error Cases Tests
    // ============================================

    function test_RevertWhen_BalanceOfZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidOwner.selector, address(0)));
        token.balanceOf(address(0));
    }

    function test_RevertWhen_OwnerOfNonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.ownerOf(1);
    }

    function test_RevertWhen_GetApprovedNonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.getApproved(1);
    }

    function test_RevertWhen_TokenURINonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, 1));
        token.tokenURI(1);
    }

    // ============================================
    // Enumeration Bug Fix Tests
    // ============================================

    function test_EnumerationBugFix_MintSetsOwner() public {
        // This test specifically verifies that the bug fix in our harness
        // correctly sets the ownerOf mapping when minting
        token.mint(alice, 1);
        
        // Verify the token is properly owned
        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
        
        // Verify enumeration works correctly
        assertEq(token.totalSupply(), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
    }

    function test_EnumerationBugFix_MintMultipleTokens() public {
        // Test that the bug fix works for multiple tokens
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(bob, 3);
        
        // Verify all tokens are properly owned
        assertEq(token.ownerOf(1), alice);
        assertEq(token.ownerOf(2), alice);
        assertEq(token.ownerOf(3), bob);
        
        // Verify enumeration is correct
        assertEq(token.totalSupply(), 3);
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 3);
    }

    function test_EnumerationBugFix_TransferAfterMint() public {
        // Test that transfers work correctly after the bug fix
        token.mint(alice, 1);
        
        // Verify initial state
        assertEq(token.ownerOf(1), alice);
        assertEq(token.balanceOf(alice), 1);
        
        // Transfer should work correctly
        vm.prank(alice);
        token.transferFrom(alice, bob, 1);
        
        // Verify transfer worked
        assertEq(token.ownerOf(1), bob);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 1);
        
        // Verify enumeration updated correctly
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 1);
    }

    function test_EnumerationBugFix_ApprovalAfterMint() public {
        // Test that approvals work correctly after the bug fix
        token.mint(alice, 1);
        
        // Verify initial state
        assertEq(token.ownerOf(1), alice);
        
        // Approval should work correctly
        vm.prank(alice);
        token.approve(bob, 1);
        
        // Verify approval worked
        assertEq(token.getApproved(1), bob);
        
        // Transfer using approval should work
        vm.prank(bob);
        token.transferFrom(alice, charlie, 1);
        
        // Verify transfer worked
        assertEq(token.ownerOf(1), charlie);
    }

    function test_EnumerationBugFix_BurnAfterMint() public {
        // Test that burning works correctly after the bug fix
        token.mint(alice, 1);
        
        // Verify initial state
        assertEq(token.ownerOf(1), alice);
        assertEq(token.totalSupply(), 1);
        
        // Burn should work correctly
        vm.prank(alice);
        token.burn(1);
        
        // Verify burn worked
        assertEq(token.totalSupply(), 0);
        assertEq(token.balanceOf(alice), 0);
        
        // Verify token no longer exists
        vm.expectRevert();
        token.ownerOf(1);
    }

    function test_EnumerationBugFix_ComplexScenario() public {
        // Test a complex scenario that would fail with the original buggy library
        // Mint multiple tokens to different owners
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(bob, 3);
        token.mint(charlie, 4);
        
        // Verify all tokens are properly owned
        assertEq(token.ownerOf(1), alice);
        assertEq(token.ownerOf(2), alice);
        assertEq(token.ownerOf(3), bob);
        assertEq(token.ownerOf(4), charlie);
        
        // Verify enumeration
        assertEq(token.totalSupply(), 4);
        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.balanceOf(charlie), 1);
        
        // Perform transfers
        vm.prank(alice);
        token.transferFrom(alice, bob, 1);
        
        vm.prank(bob);
        token.transferFrom(bob, charlie, 3);
        
        // Verify final state
        assertEq(token.ownerOf(1), bob);
        assertEq(token.ownerOf(2), alice);
        assertEq(token.ownerOf(3), charlie);
        assertEq(token.ownerOf(4), charlie);
        
        // Verify enumeration updated correctly
        assertEq(token.balanceOf(alice), 1);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.balanceOf(charlie), 2);
        
        assertEq(token.tokenOfOwnerByIndex(alice, 0), 2);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(charlie, 0), 4);
        assertEq(token.tokenOfOwnerByIndex(charlie, 1), 3);
    }

    function testFuzz_EnumerationBugFix_ComplexScenario(uint256 numTokens) public {
        vm.assume(numTokens > 0 && numTokens < 50);
        
        // Mint tokens to alice
        for (uint256 i = 1; i <= numTokens; i++) {
            token.mint(alice, i);
            assertEq(token.ownerOf(i), alice);
        }
        
        // Verify enumeration
        assertEq(token.totalSupply(), numTokens);
        assertEq(token.balanceOf(alice), numTokens);
        
        // Transfer half to bob
        uint256 halfTokens = numTokens / 2;
        for (uint256 i = 1; i <= halfTokens; i++) {
            vm.prank(alice);
            token.transferFrom(alice, bob, i);
            assertEq(token.ownerOf(i), bob);
        }
        
        // Verify final enumeration
        assertEq(token.totalSupply(), numTokens);
        assertEq(token.balanceOf(alice), numTokens - halfTokens);
        assertEq(token.balanceOf(bob), halfTokens);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintTransferBurn_Flow() public {
        token.mint(alice, 1);
        assertEq(token.ownerOf(1), alice);
        assertEq(token.totalSupply(), 1);

        vm.prank(alice);
        token.transferFrom(alice, bob, 1);
        assertEq(token.ownerOf(1), bob);
        assertEq(token.totalSupply(), 1);

        vm.prank(bob);
        token.burn(1);
        assertEq(token.totalSupply(), 0);

        vm.expectRevert();
        token.ownerOf(1);
    }

    function test_ApproveTransferFromBurn_Flow() public {
        token.mint(alice, 1);

        vm.prank(alice);
        token.approve(bob, 1);

        vm.prank(bob);
        token.transferFrom(alice, charlie, 1);
        assertEq(token.ownerOf(1), charlie);

        vm.prank(charlie);
        token.burn(1);
        assertEq(token.totalSupply(), 0);

        vm.expectRevert();
        token.ownerOf(1);
    }

    function test_EnumerationAfterMultipleTransfers() public {
        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(alice, 3);
        token.mint(alice, 4);

        assertEq(token.balanceOf(alice), 4);
        assertEq(token.totalSupply(), 4);

        vm.prank(alice);
        token.transferFrom(alice, bob, 2);

        assertEq(token.balanceOf(alice), 3);
        assertEq(token.balanceOf(bob), 1);
        assertEq(token.totalSupply(), 4);

        vm.prank(alice);
        token.transferFrom(alice, bob, 4);

        assertEq(token.balanceOf(alice), 2);
        assertEq(token.balanceOf(bob), 2);

        assertEq(token.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(token.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(token.tokenOfOwnerByIndex(bob, 0), 2);
        assertEq(token.tokenOfOwnerByIndex(bob, 1), 4);
    }
}
