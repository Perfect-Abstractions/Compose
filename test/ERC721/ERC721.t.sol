// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC721Facet} from "../../src/ERC721/ERC721/ERC721Facet.sol";
import {LibERC721} from "../../src/ERC721/ERC721/libraries/LibERC721.sol";
import {IERC721} from "../../src/interfaces/IERC721.sol";
import {IERC721Receiver} from "../../src/interfaces/IERC721.sol";

contract ERC721ReceiverMock is IERC721Receiver {
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;
    bool public shouldRevert = false;
    bool public shouldReturnInvalidSelector = false;

    function onERC721Received(address, address, uint256, bytes calldata) external override returns (bytes4) {
        if (shouldRevert) {
            revert("ERC721ReceiverMock: reverting");
        }
        if (shouldReturnInvalidSelector) {
            return 0x00000000;
        }
        return _ERC721_RECEIVED;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setShouldReturnInvalidSelector(bool _shouldReturnInvalidSelector) external {
        shouldReturnInvalidSelector = _shouldReturnInvalidSelector;
    }
}

contract TestableERC721Facet is ERC721Facet {
    function initialize(string memory _name, string memory _symbol, string memory _baseURI) external {
        ERC721Storage storage s = getStorage();
        s.name = _name;
        s.symbol = _symbol;
        s.baseURI = _baseURI;
    }

    function mint(address _to, uint256 _tokenId) external {
        LibERC721.mint(_to, _tokenId);
    }

    function burn(uint256 _tokenId) external {
        LibERC721.burn(_tokenId);
    }
}

contract ERC721Test is Test {
    TestableERC721Facet public erc721;
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public operator = address(0x4);
    ERC721ReceiverMock public receiver;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setUp() public {
        erc721 = new TestableERC721Facet();
        receiver = new ERC721ReceiverMock();
        
        vm.startPrank(owner);
        erc721.initialize("TestNFT", "TNFT", "https://api.example.com/metadata/");
        vm.stopPrank();
    }

    function test_Initialize() public {
        assertEq(erc721.name(), "TestNFT");
        assertEq(erc721.symbol(), "TNFT");
        
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        assertEq(erc721.tokenURI(1), "https://api.example.com/metadata/1");
    }

    function test_Mint() public {
        vm.prank(owner);
        erc721.mint(user1, 1);
        
        assertEq(erc721.ownerOf(1), user1);
        assertEq(erc721.balanceOf(user1), 1);
    }

    function test_MintMultiple() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.mint(user1, 2);
        erc721.mint(user2, 3);
        vm.stopPrank();
        
        assertEq(erc721.balanceOf(user1), 2);
        assertEq(erc721.balanceOf(user2), 1);
        assertEq(erc721.ownerOf(1), user1);
        assertEq(erc721.ownerOf(2), user1);
        assertEq(erc721.ownerOf(3), user2);
    }

    function test_Burn() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        erc721.burn(1);
        vm.stopPrank();
        
        vm.expectRevert();
        erc721.ownerOf(1);
    }

    function test_TransferFrom() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
        assertEq(erc721.balanceOf(user1), 0);
        assertEq(erc721.balanceOf(user2), 1);
    }

    function test_SafeTransferFrom() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.safeTransferFrom(user1, user2, 1);
        
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_SafeTransferFromWithData() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.safeTransferFrom(user1, user2, 1, "0x1234");
        
        assertEq(erc721.ownerOf(1), user2);
    }

    function test_SafeTransferFromToContract() public {
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.prank(user1);
        erc721.safeTransferFrom(user1, address(receiver), 1);
        
        assertEq(erc721.ownerOf(1), address(receiver));
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

    function test_ReceiverRevert() public {
        receiver.setShouldRevert(true);
        
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.expectRevert();
        vm.prank(user1);
        erc721.safeTransferFrom(user1, address(receiver), 1);
    }

    function test_ReceiverInvalidSelector() public {
        receiver.setShouldReturnInvalidSelector(true);
        
        vm.startPrank(owner);
        erc721.mint(user1, 1);
        vm.stopPrank();
        
        vm.expectRevert();
        vm.prank(user1);
        erc721.safeTransferFrom(user1, address(receiver), 1);
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

    function testFuzz_MintAndTransfer(uint256 tokenId) public {
        vm.assume(tokenId > 0);
        
        vm.startPrank(owner);
        erc721.mint(user1, tokenId);
        vm.stopPrank();
        
        assertEq(erc721.ownerOf(tokenId), user1);
        
        vm.prank(user1);
        erc721.transferFrom(user1, user2, tokenId);
        
        assertEq(erc721.ownerOf(tokenId), user2);
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
}
