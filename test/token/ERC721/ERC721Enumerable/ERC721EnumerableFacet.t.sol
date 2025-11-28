// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721EnumerableFacetHarness} from "./harnesses/ERC721EnumerableFacetHarness.sol";
import {ERC721EnumerableFacet} from "../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableFacet.sol";

contract ERC721EnumerableFacetTest is Test {
    ERC721EnumerableFacetHarness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    string constant BASE_URI = "https://example.com/api/nft/";

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _to, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new ERC721EnumerableFacetHarness();
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

    function test_TokenURI() public {
        uint256 tokenId = 1;
        string memory expectedURI = string(abi.encodePacked(BASE_URI, "1"));

        harness.mint(alice, tokenId);

        string memory tokenURI = harness.tokenURI(tokenId);
        assertEq(tokenURI, expectedURI);
    }

    function test_TokenURIWithZeroTokenId() public {
        uint256 tokenId = 0;
        string memory expectedURI = string(abi.encodePacked(BASE_URI, "0"));

        harness.mint(alice, tokenId);

        string memory tokenURI = harness.tokenURI(tokenId);
        assertEq(tokenURI, expectedURI);
    }

    function test_TokenURIRevertWhenNonexistent() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, tokenId));
        harness.tokenURI(tokenId);
    }

    /**
     * ============================================
     * Balance and Ownership Tests
     * ============================================
     */

    function test_BalanceOf() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(bob, 3);

        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);
        assertEq(harness.balanceOf(charlie), 0);
    }

    function test_BalanceOfRevertWhenZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidOwner.selector, address(0)));
        harness.balanceOf(address(0));
    }

    function test_OwnerOf() public {
        uint256 tokenId = 42;
        harness.mint(alice, tokenId);

        assertEq(harness.ownerOf(tokenId), alice);
    }

    function test_OwnerOfRevertWhenNonexistent() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, tokenId));
        harness.ownerOf(tokenId);
    }

    /**
     * ============================================
     * Enumeration Tests
     * ============================================
     */

    function test_TotalSupply() public {
        assertEq(harness.totalSupply(), 0);

        harness.mint(alice, 1);
        assertEq(harness.totalSupply(), 1);

        harness.mint(bob, 2);
        assertEq(harness.totalSupply(), 2);

        harness.mint(charlie, 3);
        assertEq(harness.totalSupply(), 3);
    }

    function test_TokenOfOwnerByIndex() public {
        harness.mint(alice, 10);
        harness.mint(alice, 20);
        harness.mint(alice, 30);

        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 10);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 20);
        assertEq(harness.tokenOfOwnerByIndex(alice, 2), 30);
    }

    function test_TokenOfOwnerByIndexMultipleTokens() public {
        harness.mint(alice, 1);
        harness.mint(bob, 2);
        harness.mint(alice, 3);
        harness.mint(bob, 4);

        assertEq(harness.tokenOfOwnerByIndex(alice, 0), 1);
        assertEq(harness.tokenOfOwnerByIndex(alice, 1), 3);
        assertEq(harness.tokenOfOwnerByIndex(bob, 0), 2);
        assertEq(harness.tokenOfOwnerByIndex(bob, 1), 4);
    }

    function test_TokenOfOwnerByIndexRevertWhenOutOfBounds() public {
        harness.mint(alice, 1);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721OutOfBoundsIndex.selector, alice, 1));
        harness.tokenOfOwnerByIndex(alice, 1);
    }

    /**
     * ============================================
     * Approval Tests
     * ============================================
     */

    function test_Approve() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, tokenId);
        harness.approve(bob, tokenId);

        assertEq(harness.getApproved(tokenId), bob);
    }

    function test_ApproveByOperator() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.setApprovalForAll(charlie, true);

        vm.prank(charlie);
        harness.approve(bob, tokenId);

        assertEq(harness.getApproved(tokenId), bob);
    }

    function test_ApproveSelfApproval() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.approve(alice, tokenId);

        assertEq(harness.getApproved(tokenId), alice);
    }

    function test_ApproveClearsOnTransfer() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.approve(bob, tokenId);

        vm.prank(alice);
        harness.transferFrom(alice, charlie, tokenId);

        assertEq(harness.getApproved(tokenId), address(0));
    }

    function test_ApproveRevertWhenNonexistent() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, tokenId));
        vm.prank(alice);
        harness.approve(bob, tokenId);
    }

    function test_ApproveRevertWhenUnauthorized() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidApprover.selector, bob));
        vm.prank(bob);
        harness.approve(charlie, tokenId);
    }

    function test_GetApproved() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        assertEq(harness.getApproved(tokenId), address(0));

        vm.prank(alice);
        harness.approve(bob, tokenId);

        assertEq(harness.getApproved(tokenId), bob);
    }

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(alice, bob, true);
        harness.setApprovalForAll(bob, true);

        assertTrue(harness.isApprovedForAll(alice, bob));

        vm.prank(alice);
        harness.setApprovalForAll(bob, false);

        assertFalse(harness.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAllRevertWhenZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidOperator.selector, address(0)));
        vm.prank(alice);
        harness.setApprovalForAll(address(0), true);
    }

    function test_IsApprovedForAll() public {
        assertFalse(harness.isApprovedForAll(alice, bob));

        vm.prank(alice);
        harness.setApprovalForAll(bob, true);

        assertTrue(harness.isApprovedForAll(alice, bob));
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
        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.balanceOf(bob), 1);
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

    function test_TransferFromToSelf() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.transferFrom(alice, alice, tokenId);

        assertEq(harness.ownerOf(tokenId), alice);
        assertEq(harness.balanceOf(alice), 1);
    }

    function test_TransferFromUpdatesEnumeration() public {
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

    function test_TransferFromRevertWhenNonexistent() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721NonexistentToken.selector, tokenId));
        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);
    }

    function test_TransferFromRevertWhenUnauthorized() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InsufficientApproval.selector, bob, tokenId));
        vm.prank(bob);
        harness.transferFrom(alice, charlie, tokenId);
    }

    function test_TransferFromRevertWhenZeroAddress() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableFacet.ERC721InvalidReceiver.selector, address(0)));
        vm.prank(alice);
        harness.transferFrom(alice, address(0), tokenId);
    }

    function test_TransferFromRevertWhenIncorrectOwner() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableFacet.ERC721IncorrectOwner.selector, bob, tokenId, alice)
        );
        vm.prank(alice);
        harness.transferFrom(bob, charlie, tokenId);
    }

    function test_SafeTransferFrom() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, tokenId);

        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_SafeTransferFromWithData() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, tokenId, "test data");

        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_SafeTransferFromToEOA() public {
        uint256 tokenId = 1;
        harness.mint(alice, tokenId);

        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, tokenId);

        assertEq(harness.ownerOf(tokenId), bob);
    }

    /**
     * ============================================
     * Fuzz Tests
     * ============================================
     */

    function test_ApproveFuzz(address owner, address operator, uint256 tokenId) public {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(owner, tokenId);

        vm.prank(owner);
        harness.approve(operator, tokenId);

        assertEq(harness.getApproved(tokenId), operator);
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

    function test_SetApprovalForAllFuzz(address owner, address operator) public {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));

        vm.prank(owner);
        harness.setApprovalForAll(operator, true);

        assertTrue(harness.isApprovedForAll(owner, operator));
    }
}
