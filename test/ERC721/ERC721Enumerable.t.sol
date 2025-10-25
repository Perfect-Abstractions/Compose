// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721EnumerableFacet} from "../../src/ERC721/ERC721Enumerable/ERC721EnumerableFacet.sol";
import {LibERC721 as LibERC721Enumerable} from "../../src/ERC721/ERC721Enumerable/libraries/LibERC721Enumerable.sol";
import {IERC721Enumerable} from "../../src/interfaces/IERC721Enumerable.sol";
import {IERC721Receiver} from "../../src/interfaces/IERC721.sol";

contract TestableERC721EnumerableFacet is ERC721EnumerableFacet {
    function mint(address _to, uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        if (_to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        if (s.ownerOf[_tokenId] != address(0)) {
            revert ERC721InvalidSender(address(0));
        }

        s.ownerOf[_tokenId] = _to;
        s.ownedTokensIndexOf[_tokenId] = s.ownedTokensOf[_to].length;
        s.ownedTokensOf[_to].push(_tokenId);
        s.allTokensIndexOf[_tokenId] = s.allTokens.length;
        s.allTokens.push(_tokenId);
        emit Transfer(address(0), _to, _tokenId);
    }

    function burn(uint256 _tokenId) external {
        ERC721EnumerableStorage storage s = getStorage();
        address owner = s.ownerOf[_tokenId];
        if (owner == address(0)) {
            revert ERC721NonexistentToken(_tokenId);
        }
        if (msg.sender != owner) {
            if (!s.isApprovedForAll[owner][msg.sender] && msg.sender != s.approved[_tokenId]) {
                revert ERC721InsufficientApproval(msg.sender, _tokenId);
            }
        }

        delete s.ownerOf[_tokenId];
        delete s.approved[_tokenId];

        uint256 tokenIndex = s.ownedTokensIndexOf[_tokenId];
        uint256 lastTokenIndex = s.ownedTokensOf[owner].length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.ownedTokensOf[owner][lastTokenIndex];
            s.ownedTokensOf[owner][tokenIndex] = lastTokenId;
            s.ownedTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.ownedTokensOf[owner].pop();

        tokenIndex = s.allTokensIndexOf[_tokenId];
        lastTokenIndex = s.allTokens.length - 1;
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = s.allTokens[lastTokenIndex];
            s.allTokens[tokenIndex] = lastTokenId;
            s.allTokensIndexOf[lastTokenId] = tokenIndex;
        }
        s.allTokens.pop();
        emit Transfer(owner, address(0), _tokenId);
    }
}

contract ERC721EnumerableTest is Test {
    TestableERC721EnumerableFacet public erc721;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public operator = address(0x4);

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setUp() public {
        erc721 = new TestableERC721EnumerableFacet();
    }

    function test_Initialize() public {
        assertEq(erc721.totalSupply(), 0);
    }

    function test_Mint() public {
        vm.prank(owner);
        erc721.mint(user1, 1);
        
        assertEq(erc721.ownerOf(1), user1);
        assertEq(erc721.balanceOf(user1), 1);
        assertEq(erc721.totalSupply(), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 1);
    }

    function test_MintMultiple() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        erc721.mint(user2, 3);
        vm.stopPrank();
        
        assertEq(erc721.balanceOf(user1), 2);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.totalSupply(), 3);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 1), 2);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 0), 3);
    }

    function test_Burn() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.burn(1);
        
        assertEq(erc721.totalSupply(), 0);
        assertEq(erc721.balanceOf(user1), 0);
        
        vm.expectRevert();
        erc721.tokenOfOwnerByIndex(user1, 0);
    }

    function test_TransferFrom() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
        assertEq(erc721.balanceOf(user1), 1);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 2);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 0), 1);
    }

    function test_TransferFromUpdatesIndices() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        erc721.mint(user1, 3);
        vm.stopPrank();
        
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 1), 2);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 2), 3);
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 2);
        
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 1), 3);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 0), 2);
    }

    function test_SafeTransferFrom() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.safeTransferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 0), 1);
    }

    function test_SafeTransferFromWithData() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.safeTransferFrom(user1, user2, 1, "0x1234");
        
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_Approve() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.approve(user2, 1);
        
        assertEq(erc721.getApproved(1), user2);
    }

    function test_SetApprovalForAll() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.setApprovalForAll(operator, true);
        
        assertTrue(erc721.isApprovedForAll(user1, operator));
        
        vm.prank(operator);
        erc721.transferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_Events() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.expectEmit(true, true, true, true);
        emit Transfer(user1, user2, 1);
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 1);
        
        vm.expectEmit(true, true, true, true);
        emit Approval(user2, operator, 1);
        vm.prank(user2);
        erc721.approve(operator, 1);
        
        vm.expectEmit(true, true, true, true);
        emit ApprovalForAll(user2, operator, true);
        vm.prank(user2);
        erc721.setApprovalForAll(operator, true);
    }

    function test_ErrorCases() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.expectRevert();
        erc721.balanceOf(address(0));
        
        vm.expectRevert();
        erc721.ownerOf(999);
        
        vm.expectRevert();
        erc721.getApproved(999);
        
        vm.expectRevert();
        erc721.tokenURI(999);
        
        vm.expectRevert();
        erc721.tokenOfOwnerByIndex(user1, 1);
        
        vm.expectRevert();
        vm.prank(user2);
        erc721.transferFrom(user1, user2, 1);
        
        vm.expectRevert();
        vm.prank(user2);
        erc721.approve(user2, 1);
        
        vm.expectRevert();
        erc721.setApprovalForAll(address(0), true);
        
        vm.expectRevert();
        vm.prank(user1);
        erc721.transferFrom(user1, address(0), 1);
    }

    function test_ApprovalClearedOnTransfer() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.approve(user2, 1);
        assertEq(erc721.getApproved(1), user2);
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 1);
        assertEq(erc721.getApproved(1), address(0));
    }

    function test_OperatorCanTransfer() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.setApprovalForAll(operator, true);
        
        vm.prank(operator);
        erc721.transferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_ApprovedCanTransfer() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.approve(operator, 1);
        
        vm.prank(operator);
        erc721.transferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_EnumerationAfterMultipleTransfers() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        erc721.mint(user1, 3);
        erc721.mint(user1, 4);
        vm.stopPrank();
        
        assertEq(erc721.balanceOf(user1), 4);
        assertEq(erc721.totalSupply(), 4);
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 2);
        
        assertEq(erc721.balanceOf(user1), 3);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.totalSupply(), 4);
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 4);
        
        assertEq(erc721.balanceOf(user1), 2);
        assertEq(erc721.balanceOf(user2), 2);
        
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 1), 3);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 0), 2);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 1), 4);
    }

    function test_EnumerationAfterBurn() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        erc721.mint(user1, 3);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.burn(2);
        
        assertEq(erc721.balanceOf(user1), 2);
        assertEq(erc721.totalSupply(), 2);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 1), 3);
    }

    function testFuzz_MintAndTransfer(uint256 tokenId) public {
        vm.assume(tokenId > 0);
        
        vm.startPrank(owner);
        erc721.mint(user1, tokenId);
        vm.stopPrank();
        
        assertEq(erc721.ownerOf(tokenId), user1);
        assertEq(erc721.totalSupply(), 1);
        assertEq(erc721.tokenOfOwnerByIndex(user1, 0), tokenId);
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, tokenId);
        
        assertEq(erc721.ownerOf(tokenId), user2);
        assertEq(erc721.tokenOfOwnerByIndex(user2, 0), tokenId);
    }

    function testFuzz_ApproveAndTransfer(uint256 tokenId) public {
        vm.assume(tokenId > 0);
        
        vm.startPrank(owner);
        erc721.mint(user1, tokenId);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.approve(operator, tokenId);
        
        vm.prank(operator);
        erc721.transferFrom(user1, user2, tokenId);
        
        assertEq(erc721.ownerOf(tokenId), user2);
    }

    function testFuzz_Enumeration(uint256 numTokens) public {
        vm.assume(numTokens > 0 && numTokens < 100);
        
        vm.startPrank(owner);
        for (uint256 i = 1; i <= numTokens; i++) {
            erc721.mint(user1, i);
        }
        vm.stopPrank();
        
        assertEq(erc721.balanceOf(user1), numTokens);
        assertEq(erc721.totalSupply(), numTokens);
        
        for (uint256 i = 0; i < numTokens; i++) {
            assertEq(erc721.tokenOfOwnerByIndex(user1, i), i + 1);
        }
    }
}
