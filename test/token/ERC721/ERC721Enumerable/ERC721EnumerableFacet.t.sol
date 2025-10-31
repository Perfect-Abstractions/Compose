// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721EnumerableFacetHarness} from "./harnesses/ERC721EnumerableFacetHarness.sol";

contract ERC721EnumerableFacetTest is Test {
    ERC721EnumerableFacetHarness public facet;

    address public alice;
    address public bob;
    address public charlie;
    address public operator;

    string constant TOKEN_NAME = "Test NFT";
    string constant TOKEN_SYMBOL = "TNFT";
    string constant BASE_URI = "https://example.com/token/";

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _to, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        operator = makeAddr("operator");

        facet = new ERC721EnumerableFacetHarness();
        facet.initialize(TOKEN_NAME, TOKEN_SYMBOL, BASE_URI);
    }

    // ============================================
    // Metadata Tests
    // ============================================

    function test_Name() public view {
        assertEq(facet.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(facet.symbol(), TOKEN_SYMBOL);
    }

    function test_TokenURI() public {
        facet.mint(alice, 1);
        assertEq(facet.tokenURI(1), "https://example.com/token/1");
    }

    function test_TokenURI_Zero() public {
        facet.mint(alice, 0);
        assertEq(facet.tokenURI(0), "https://example.com/token/0");
    }

    function test_TokenURI_LargeNumber() public {
        uint256 tokenId = 123456789;
        facet.mint(alice, tokenId);
        assertEq(facet.tokenURI(tokenId), "https://example.com/token/123456789");
    }

    function test_RevertWhen_TokenURINonexistentToken() public {
        vm.expectRevert();
        facet.tokenURI(999);
    }

    // ============================================
    // Balance and Ownership Tests
    // ============================================

    function test_BalanceOf() public {
        facet.mint(alice, 1);
        facet.mint(alice, 2);
        facet.mint(bob, 3);

        assertEq(facet.balanceOf(alice), 2);
        assertEq(facet.balanceOf(bob), 1);
        assertEq(facet.balanceOf(charlie), 0);
    }

    function test_RevertWhen_BalanceOfZeroAddress() public {
        vm.expectRevert();
        facet.balanceOf(address(0));
    }

    function test_OwnerOf() public {
        facet.mint(alice, 1);
        assertEq(facet.ownerOf(1), alice);
    }

    function test_RevertWhen_OwnerOfNonexistentToken() public {
        vm.expectRevert();
        facet.ownerOf(999);
    }

    // ============================================
    // Enumeration Tests
    // ============================================

    function test_TotalSupply() public {
        assertEq(facet.totalSupply(), 0);

        facet.mint(alice, 1);
        assertEq(facet.totalSupply(), 1);

        facet.mint(bob, 2);
        assertEq(facet.totalSupply(), 2);

        vm.prank(alice);
        facet.burn(1);
        assertEq(facet.totalSupply(), 1);
    }

    function test_TokenOfOwnerByIndex() public {
        facet.mint(alice, 10);
        facet.mint(alice, 20);
        facet.mint(alice, 30);

        assertEq(facet.tokenOfOwnerByIndex(alice, 0), 10);
        assertEq(facet.tokenOfOwnerByIndex(alice, 1), 20);
        assertEq(facet.tokenOfOwnerByIndex(alice, 2), 30);
    }

    function test_RevertWhen_TokenOfOwnerByIndexOutOfBounds() public {
        facet.mint(alice, 1);

        vm.expectRevert();
        facet.tokenOfOwnerByIndex(alice, 1); // Index 1 is out of bounds
    }

    // ============================================
    // Approval Tests
    // ============================================

    function test_Approve() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 1);
        facet.approve(bob, 1);

        assertEq(facet.getApproved(1), bob);
    }

    function test_Approve_OwnerCanApprove() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.approve(bob, 1);

        assertEq(facet.getApproved(1), bob);
    }

    function test_Approve_OperatorCanApprove() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.setApprovalForAll(operator, true);

        vm.prank(operator);
        facet.approve(bob, 1);

        assertEq(facet.getApproved(1), bob);
    }

    function test_RevertWhen_ApproveNonexistentToken() public {
        vm.prank(alice);
        vm.expectRevert();
        facet.approve(bob, 999);
    }

    function test_RevertWhen_ApproveUnauthorized() public {
        facet.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert();
        facet.approve(charlie, 1);
    }

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, operator, true);
        facet.setApprovalForAll(operator, true);

        assertTrue(facet.isApprovedForAll(alice, operator));
    }

    function test_SetApprovalForAll_Revoke() public {
        vm.startPrank(alice);
        facet.setApprovalForAll(operator, true);
        facet.setApprovalForAll(operator, false);
        vm.stopPrank();

        assertFalse(facet.isApprovedForAll(alice, operator));
    }

    function test_RevertWhen_SetApprovalForAllZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert();
        facet.setApprovalForAll(address(0), true);
    }

    function test_GetApproved() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.approve(bob, 1);

        assertEq(facet.getApproved(1), bob);
    }

    function test_RevertWhen_GetApprovedNonexistentToken() public {
        vm.expectRevert();
        facet.getApproved(999);
    }

    function test_IsApprovedForAll() public {
        vm.prank(alice);
        facet.setApprovalForAll(operator, true);

        assertTrue(facet.isApprovedForAll(alice, operator));
        assertFalse(facet.isApprovedForAll(alice, bob));
    }

    // ============================================
    // Transfer Tests
    // ============================================

    function test_TransferFrom_ByOwner() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        facet.transferFrom(alice, bob, 1);

        assertEq(facet.ownerOf(1), bob);
        assertEq(facet.balanceOf(alice), 0);
        assertEq(facet.balanceOf(bob), 1);
    }

    function test_TransferFrom_ByApprovedAddress() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.approve(bob, 1);

        vm.prank(bob);
        facet.transferFrom(alice, charlie, 1);

        assertEq(facet.ownerOf(1), charlie);
    }

    function test_TransferFrom_ByOperator() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.setApprovalForAll(operator, true);

        vm.prank(operator);
        facet.transferFrom(alice, bob, 1);

        assertEq(facet.ownerOf(1), bob);
    }

    function test_TransferFrom_ClearsApproval() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.approve(bob, 1);

        vm.prank(alice);
        facet.transferFrom(alice, charlie, 1);

        assertEq(facet.getApproved(1), address(0));
    }

    function test_RevertWhen_TransferFromIncorrectOwner() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert();
        facet.transferFrom(bob, charlie, 1);
    }

    function test_RevertWhen_TransferFromToZeroAddress() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        vm.expectRevert();
        facet.transferFrom(alice, address(0), 1);
    }

    function test_RevertWhen_TransferFromUnauthorized() public {
        facet.mint(alice, 1);

        vm.prank(bob);
        vm.expectRevert();
        facet.transferFrom(alice, bob, 1);
    }

    // ============================================
    // SafeTransferFrom Tests
    // ============================================

    function test_SafeTransferFrom_ToEOA() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        facet.safeTransferFrom(alice, bob, 1);

        assertEq(facet.ownerOf(1), bob);
    }

    function test_SafeTransferFrom_WithData() public {
        facet.mint(alice, 1);
        bytes memory data = "test data";

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, 1);
        facet.safeTransferFrom(alice, bob, 1, data);

        assertEq(facet.ownerOf(1), bob);
    }

    function test_SafeTransferFrom_ByOperator() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.setApprovalForAll(operator, true);

        vm.prank(operator);
        facet.safeTransferFrom(alice, bob, 1);

        assertEq(facet.ownerOf(1), bob);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintApproveTransfer_Flow() public {
        // Mint token to alice
        facet.mint(alice, 1);
        assertEq(facet.ownerOf(1), alice);

        // Alice approves bob
        vm.prank(alice);
        facet.approve(bob, 1);
        assertEq(facet.getApproved(1), bob);

        // Bob transfers to charlie
        vm.prank(bob);
        facet.transferFrom(alice, charlie, 1);
        assertEq(facet.ownerOf(1), charlie);

        // Approval should be cleared
        assertEq(facet.getApproved(1), address(0));
    }

    function test_MintSetOperatorTransfer_Flow() public {
        // Mint token to alice
        facet.mint(alice, 1);

        // Alice sets operator
        vm.prank(alice);
        facet.setApprovalForAll(operator, true);

        // Operator transfers
        vm.prank(operator);
        facet.transferFrom(alice, bob, 1);

        assertEq(facet.ownerOf(1), bob);
    }

    function test_MultipleTokensEnumeration() public {
        // Mint multiple tokens
        facet.mint(alice, 1);
        facet.mint(alice, 2);
        facet.mint(bob, 3);
        facet.mint(bob, 4);
        facet.mint(charlie, 5);

        // Check total supply
        assertEq(facet.totalSupply(), 5);

        // Check balances
        assertEq(facet.balanceOf(alice), 2);
        assertEq(facet.balanceOf(bob), 2);
        assertEq(facet.balanceOf(charlie), 1);

        // Check enumeration
        assertEq(facet.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(facet.tokenOfOwnerByIndex(alice, 1), 2);
        assertEq(facet.tokenOfOwnerByIndex(bob, 0), 3);
        assertEq(facet.tokenOfOwnerByIndex(bob, 1), 4);
        assertEq(facet.tokenOfOwnerByIndex(charlie, 0), 5);

        // Transfer one token
        vm.prank(alice);
        facet.transferFrom(alice, bob, 1);

        // Check updated state
        assertEq(facet.balanceOf(alice), 1);
        assertEq(facet.balanceOf(bob), 3);
        assertEq(facet.ownerOf(1), bob);
    }

    function test_BurnAndEnumeration() public {
        // Mint tokens
        facet.mint(alice, 1);
        facet.mint(alice, 2);
        facet.mint(alice, 3);

        assertEq(facet.totalSupply(), 3);
        assertEq(facet.balanceOf(alice), 3);

        // Burn middle token
        vm.prank(alice);
        facet.burn(2);

        // Check updated state
        assertEq(facet.totalSupply(), 2);
        assertEq(facet.balanceOf(alice), 2);

        // Check remaining tokens
        assertEq(facet.ownerOf(1), alice);
        assertEq(facet.ownerOf(3), alice);
    }

    // ============================================
    // Edge Cases
    // ============================================

    function test_ApprovalPersistsAcrossQueries() public {
        facet.mint(alice, 1);

        vm.prank(alice);
        facet.approve(bob, 1);

        assertEq(facet.getApproved(1), bob);
        assertEq(facet.getApproved(1), bob); // Should still be bob
    }

    function test_OperatorApprovalPersists() public {
        vm.prank(alice);
        facet.setApprovalForAll(operator, true);

        assertTrue(facet.isApprovedForAll(alice, operator));
        assertTrue(facet.isApprovedForAll(alice, operator)); // Should still be true
    }

    function test_ZeroBalanceOwner() public view {
        assertEq(facet.balanceOf(alice), 0);
    }

    function testFuzz_TokenURI(uint256 tokenId) public {
        vm.assume(tokenId > 0 && tokenId < type(uint128).max);
        
        facet.mint(alice, tokenId);
        
        string memory uri = facet.tokenURI(tokenId);
        // URI should contain the base URI
        assertTrue(bytes(uri).length > 0);
    }
}

