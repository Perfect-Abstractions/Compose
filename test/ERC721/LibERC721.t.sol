// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC721Harness} from "./harnesses/LibERC721Harness.sol";
import {LibERC721} from "../../src/token/ERC721/ERC721/LibERC721.sol";

contract LibERC721Test is Test {
    LibERC721Harness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test NFT";
    string constant TOKEN_SYMBOL = "TNFT";
    string constant BASE_URI = "https://api.example.com/metadata/";

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _tokenId);
    event ApprovalForAll(address indexed _owner, address indexed _operator, bool _approved);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new LibERC721Harness();
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

    function test_InitialBalance() public view {
        assertEq(harness.balanceOf(alice), 0);
    }

    // ============================================
    // Mint Tests
    // ============================================

    function test_Mint() public {
        uint256 tokenId = 1;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, tokenId);
        harness.mint(alice, tokenId);

        assertEq(harness.ownerOf(tokenId), alice);
        assertEq(harness.balanceOf(alice), 1);
    }

    function test_Mint_Multiple() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(bob, 3);

        assertEq(harness.ownerOf(1), alice);
        assertEq(harness.ownerOf(2), alice);
        assertEq(harness.ownerOf(3), bob);
        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);
    }

    function testFuzz_Mint(address to, uint256 tokenId) public {
        vm.assume(to != address(0));
        vm.assume(tokenId != 0);

        harness.mint(to, tokenId);

        assertEq(harness.ownerOf(tokenId), to);
        assertEq(harness.balanceOf(to), 1);
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
        uint256 tokenId = 1;

        harness.mint(alice, tokenId);
        assertEq(harness.ownerOf(tokenId), alice);
        assertEq(harness.balanceOf(alice), 1);

        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), tokenId);
        harness.burn(tokenId);

        assertEq(harness.balanceOf(alice), 0);
    }

    function test_Burn_EntireBalance() public {
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(alice, 3);

        assertEq(harness.balanceOf(alice), 3);

        harness.burn(1);
        harness.burn(2);
        harness.burn(3);

        assertEq(harness.balanceOf(alice), 0);
    }

    function testFuzz_Burn(uint256 tokenId) public {
        vm.assume(tokenId != 0);

        harness.mint(alice, tokenId);
        harness.burn(tokenId);

        assertEq(harness.balanceOf(alice), 0);
    }

    function test_RevertWhen_BurnNonExistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC721.ERC721NonexistentToken.selector, 1));
        harness.burn(1);
    }

    // ============================================
    // Gas Benchmark Tests
    // ============================================

    function test_GasBenchmark_Mint() public {
        uint256 gasStart = gasleft();
        harness.mint(alice, 1);
        uint256 gasUsed = gasStart - gasleft();

        // Mint should use less than 100k gas
        assertLt(gasUsed, 100_000);
    }

    function test_GasBenchmark_Burn() public {
        harness.mint(alice, 1);

        uint256 gasStart = gasleft();
        harness.burn(1);
        uint256 gasUsed = gasStart - gasleft();

        // Burn should use less than 50k gas
        assertLt(gasUsed, 50_000);
    }

    function test_GasBenchmark_MintMultiple() public {
        uint256 gasStart = gasleft();

        for (uint256 i = 1; i <= 10; i++) {
            harness.mint(alice, i);
        }

        uint256 gasUsed = gasStart - gasleft();

        // 10 mints should use less than 1M gas
        assertLt(gasUsed, 1_000_000);
    }

    function test_GasBenchmark_BurnMultiple() public {
        // Mint 10 tokens first
        for (uint256 i = 1; i <= 10; i++) {
            harness.mint(alice, i);
        }

        uint256 gasStart = gasleft();

        for (uint256 i = 1; i <= 10; i++) {
            harness.burn(i);
        }

        uint256 gasUsed = gasStart - gasleft();

        // 10 burns should use less than 500k gas
        assertLt(gasUsed, 500_000);
    }

    // ============================================
    // Integration Tests
    // ============================================

    function test_MintBurn_Flow() public {
        harness.mint(alice, 1);
        assertEq(harness.ownerOf(1), alice);
        assertEq(harness.balanceOf(alice), 1);

        harness.burn(1);
        assertEq(harness.balanceOf(alice), 0);
    }

    function test_MintMultipleBurn_Flow() public {
        // Mint multiple tokens
        harness.mint(alice, 1);
        harness.mint(alice, 2);
        harness.mint(bob, 3);

        assertEq(harness.balanceOf(alice), 2);
        assertEq(harness.balanceOf(bob), 1);

        // Burn some tokens
        harness.burn(1);
        harness.burn(3);

        assertEq(harness.balanceOf(alice), 1);
        assertEq(harness.balanceOf(bob), 0);
        assertEq(harness.ownerOf(2), alice);
    }
}
