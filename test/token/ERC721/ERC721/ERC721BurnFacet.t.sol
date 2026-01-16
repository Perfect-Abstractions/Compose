// // SPDX-License-Identifier: MIT
// pragma solidity >=0.8.30;
//
// /* Compose
//  * https://compose.diamonds
//  */
//
// import {Test} from "forge-std/Test.sol";
// import {ERC721BurnFacet} from "../../../../src/token/ERC721/ERC721/ERC721BurnFacet.sol";
// import {ERC721BurnFacetHarness} from "./harnesses/ERC721BurnFacetHarness.sol";
//
// contract ERC721BurnFacetTest is Test {
//     ERC721BurnFacetHarness public harness;
//
//     address public alice;
//     address public bob;
//     address public charlie;
//
//     function setUp() public {
//         alice = makeAddr("alice");
//         bob = makeAddr("bob");
//         charlie = makeAddr("charlie");
//
//         harness = new ERC721BurnFacetHarness();
//     }
//
//     /**
//      * ============================================
//      * Burn Tests
//      * ============================================
//      */
//
//     function test_Burn() public {
//         uint256 tokenId = 7;
//
//         harness.mint(alice, tokenId);
//         assertEq(harness.ownerOf(tokenId), alice);
//
//         vm.prank(alice);
//         harness.burn(tokenId);
//         assertEq(harness.ownerOf(tokenId), address(0));
//     }
//
//     function test_BurnFuzz(address to, uint256 tokenId) public {
//         vm.assume(to != address(0));
//         vm.assume(tokenId < type(uint256).max);
//
//         harness.mint(to, tokenId);
//         assertEq(harness.ownerOf(tokenId), to);
//
//         vm.prank(to);
//         harness.burn(tokenId);
//         assertEq(harness.ownerOf(tokenId), address(0));
//     }
//
//     function test_BurnRevertWhenNonExistentToken() public {
//         uint256 tokenId = 888;
//
//         vm.expectRevert(abi.encodeWithSelector(ERC721BurnFacet.ERC721NonexistentToken.selector, tokenId));
//         harness.burn(tokenId);
//     }
// }
