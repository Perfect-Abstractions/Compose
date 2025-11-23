// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721FacetHarness} from "./harnesses/ERC721FacetHarness.sol";
import {ERC721Facet} from "../../../../../src/token/ERC721/ERC721/ERC721Facet.sol";

contract ERC721FacetTest is Test {
    ERC721FacetHarness public harness;

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

        harness = new ERC721FacetHarness();
        harness.initialize(TOKEN_NAME, TOKEN_SYMBOL, BASE_URI);
    }

    // ============================================
    // Metadata Tests
    // ============================================

    function test_name() public view {
        assertEq(harness.name(), TOKEN_NAME);
    }

    function test_symbol() public view {
        assertEq(harness.symbol(), TOKEN_SYMBOL);
    }

    function test_baseURI() public view {
        assertEq(harness.baseURI(), BASE_URI);
    }

    // ============================================
    // TokenURI Tests
    // ============================================

    function test_tokenURI() public {
        uint256 tokenId = 1;
        string memory expectedURI = string(abi.encodePacked(BASE_URI, "1"));

        harness.mint(alice, tokenId);

        string memory tokenURI = ERC721Facet(address(harness)).tokenURI(tokenId);
        assertEq(tokenURI, expectedURI);
    }

    function test_tokenOwner() public {
        uint256 tokenId = 45;

        harness.mint(alice, tokenId);

        assertEq(harness.ownerOf(tokenId), alice);
    }

    // ============================================
    // Approve Tests
    // ============================================

    function test_Approve() public {
        uint256 tokenId = 4;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        ERC721Facet(address(harness)).approve(bob, tokenId);

        address approved = ERC721Facet(address(harness)).getApproved(tokenId);
        assertEq(approved, bob);
    }

    function test_ApproveSelfApproval() public {
        uint256 tokenId = 6;

        harness.mint(bob, tokenId);

        vm.prank(bob);
        ERC721Facet(address(harness)).approve(bob, tokenId);

        address approved = ERC721Facet(address(harness)).getApproved(tokenId);
        assertEq(approved, bob);
    }

    function test_ApproveClearsOnTransfer() public {
        uint256 tokenId = 7;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        ERC721Facet(address(harness)).approve(bob, tokenId);

        vm.prank(alice);
        ERC721Facet(address(harness)).transferFrom(alice, charlie, tokenId);

        address approved = ERC721Facet(address(harness)).getApproved(tokenId);
        assertEq(approved, address(0));
    }

    function test_ApproveFuzz(address owner, address operator, uint256 tokenId) public {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(owner != operator);
        vm.assume(tokenId < type(uint256).max);

        harness.mint(owner, tokenId);

        vm.prank(owner);
        ERC721Facet(address(harness)).approve(operator, tokenId);

        address approved = ERC721Facet(address(harness)).getApproved(tokenId);
        assertEq(approved, operator);
    }

    function test_getApproved() public {
        uint256 tokenId = 4;

        harness.mint(alice, tokenId);

        vm.prank(alice);
        ERC721Facet(address(harness)).approve(bob, tokenId);

        address approved = ERC721Facet(address(harness)).getApproved(tokenId);
        assertEq(approved, bob);

        assertEq(harness.getApproved(tokenId), bob);
    }

    // ===========================================
    // SetApprovalForAll Tests
    // ===========================================

    function test_SetApprovalForAll() public {
        vm.prank(alice);
        ERC721Facet(address(harness)).setApprovalForAll(bob, true);

        bool isApproved = ERC721Facet(address(harness)).isApprovedForAll(alice, bob);
        assertTrue(isApproved);
    }

    function test_SetApprovalForAllFuzz(address owner, address operator) public {
        vm.assume(owner != address(0));
        vm.assume(operator != address(0));
        vm.assume(owner != operator);

        vm.prank(owner);
        ERC721Facet(address(harness)).setApprovalForAll(operator, true);

        bool isApproved = ERC721Facet(address(harness)).isApprovedForAll(owner, operator);
        assertTrue(isApproved);
    }

    // ============================================
    // transferFrom tests
    // ============================================

    function test_transferFrom() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);
        assertEq(harness.ownerOf(tokenId), alice);

        vm.prank(alice);
        harness.transferFrom(alice, bob, tokenId);
        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_transferFromToSelf() public {
        uint256 tokenId = 2;

        harness.mint(charlie, tokenId);
        assertEq(harness.ownerOf(tokenId), charlie);

        vm.prank(charlie);
        harness.transferFrom(charlie, charlie, tokenId);
        assertEq(harness.ownerOf(tokenId), charlie);
    }

    function test_transferFromFuzz(address from, address to, uint256 tokenId) public {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(tokenId < type(uint256).max);

        harness.mint(from, tokenId);
        assertEq(harness.ownerOf(tokenId), from);

        vm.prank(from);
        harness.transferFrom(from, to, tokenId);
        assertEq(harness.ownerOf(tokenId), to);
    }

    function test_transferFromRevertWhenTransferFromNonExistentToken() public {
        uint256 tokenId = 999;

        vm.expectRevert(abi.encodeWithSelector(ERC721Facet.ERC721NonexistentToken.selector, tokenId));
        harness.transferFrom(alice, bob, tokenId);
    }

    // ===========================================
    // safeTransferFrom Tests
    // ===========================================

    function test_safeTransferFrom() public {
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);
        assertEq(harness.ownerOf(tokenId), alice);

        vm.prank(alice);
        harness.safeTransferFrom(alice, bob, tokenId);
        assertEq(harness.ownerOf(tokenId), bob);
    }

    function test_safeTransferFromToSelf() public {
        uint256 tokenId = 2;

        harness.mint(charlie, tokenId);
        assertEq(harness.ownerOf(tokenId), charlie);

        vm.prank(charlie);
        harness.safeTransferFrom(charlie, charlie, tokenId);
        assertEq(harness.ownerOf(tokenId), charlie);
    }

    // ====================================
    // balanceOf Tests
    // ====================================

    function test_BalanceOf() public {
        uint256 tokenId1 = 32;
        uint256 tokenId2 = 45;

        harness.mint(alice, tokenId1);
        harness.mint(alice, tokenId2);

        assertEq(harness.balanceOf(alice), 2);
    }
}
