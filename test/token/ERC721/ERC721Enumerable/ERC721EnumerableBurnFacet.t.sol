// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test} from "forge-std/Test.sol";
import {ERC721EnumerableBurnFacet} from "../../../../src/token/ERC721/ERC721Enumerable/ERC721EnumerableBurnFacet.sol";
import {ERC721EnumerableBurnFacetHarness} from "./harnesses/ERC721EnumerableBurnFacetHarness.sol";

contract ERC721EnumerableBurnFacetTest is Test {
    ERC721EnumerableBurnFacetHarness internal token;

    address internal alice;
    address internal bob;
    address internal charlie;

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _tokenId);

    function setUp() public {
        token = new ERC721EnumerableBurnFacetHarness();

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token.mint(alice, 1);
        token.mint(alice, 2);
        token.mint(bob, 3);
    }

    function test_Burn_RemovesTokenAndUpdatesSupply() public {
        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), 1);
        token.burn(1);

        assertEq(token.balanceOf(alice), 1);
        assertEq(token.totalSupply(), 2);

        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableBurnFacet.ERC721NonexistentToken.selector, 1));
        token.ownerOf(1);
    }

    function test_Burn_ByApprovedOperator() public {
        vm.prank(alice);
        token.approve(bob, 2);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), 2);
        token.burn(2);

        assertEq(token.balanceOf(alice), 1);
        assertEq(token.totalSupply(), 2);
    }

    function test_Burn_UpdatesEnumerationOrdering() public {
        vm.prank(alice);
        token.burn(1);

        uint256 remainingToken = token.tokenOfOwnerByIndex(alice, 0);
        assertEq(remainingToken, 2);

        /**
         * Ensure global enumeration shrinks
         */
        assertEq(token.totalSupply(), 2);
    }

    function test_RevertWhen_BurnWithoutApproval() public {
        vm.expectRevert(
            abi.encodeWithSelector(ERC721EnumerableBurnFacet.ERC721InsufficientApproval.selector, charlie, 2)
        );
        vm.prank(charlie);
        token.burn(2);
    }

    function test_RevertWhen_BurnNonexistentToken() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721EnumerableBurnFacet.ERC721NonexistentToken.selector, 99));
        vm.prank(alice);
        token.burn(99);
    }
}
