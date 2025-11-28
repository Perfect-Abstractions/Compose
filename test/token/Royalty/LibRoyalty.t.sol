// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibRoyaltyHarness} from "./harnesses/LibRoyaltyHarness.sol";
import {LibRoyalty} from "../../../src/token/Royalty/LibRoyalty.sol";

contract LibRoyaltyTest is Test {
    LibRoyaltyHarness public harness;

    address public alice;
    address public bob;
    address public charlie;
    address public royaltyReceiver;

    uint256 constant FEE_DENOMINATOR = 10000;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        royaltyReceiver = makeAddr("royaltyReceiver");

        harness = new LibRoyaltyHarness();
    }

    /**
     * ============================================
     * royaltyInfo Tests
     * ============================================
     */

    function test_RoyaltyInfo_NoRoyaltySet() public view {
        uint256 tokenId = 1;
        uint256 salePrice = 1 ether;

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, address(0));
        assertEq(royaltyAmount, 0);
    }

    function test_RoyaltyInfo_DefaultRoyaltyOnly() public {
        uint256 tokenId = 1;
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, salePrice * feeNumerator / FEE_DENOMINATOR);
    }

    function test_RoyaltyInfo_5PercentRoyalty() public {
        uint256 tokenId = 1;
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;
        /**
         * 500) / 10000 = 5 ether
         */
        uint256 expectedRoyalty = 5 ether;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_10PercentRoyalty() public {
        uint96 feeNumerator = 1000; // 10%
        uint256 salePrice = 50 ether;
        /**
         * 1000) / 10000 = 5 ether
         */
        uint256 expectedRoyalty = 5 ether;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_50PercentRoyalty() public {
        uint96 feeNumerator = 5000; // 50%
        uint256 salePrice = 10 ether;
        /**
         * 5000) / 10000 = 5 ether
         */
        uint256 expectedRoyalty = 5 ether;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_100PercentRoyalty() public {
        uint96 feeNumerator = 10000; // 100%
        uint256 salePrice = 1 ether;
        /**
         * 10000) / 10000 = 1 ether
         */
        uint256 expectedRoyalty = 1 ether;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_TokenSpecificRoyalty() public {
        uint256 tokenId = 5;
        uint96 defaultFeeNumerator = 500; // 5%
        uint96 tokenFeeNumerator = 750; // 7.5%
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(alice, defaultFeeNumerator);
        harness.setTokenRoyalty(tokenId, bob, tokenFeeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, bob);
        /**
         * 750) / 10000 = 7.5 ether
         */
        assertEq(royaltyAmount, 7.5 ether);
    }

    function test_RoyaltyInfo_TokenSpecificOverridesDefault() public {
        uint256 tokenId = 10;
        uint96 defaultFeeNumerator = 1000; // 10%
        uint96 tokenFeeNumerator = 250; // 2.5%
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(alice, defaultFeeNumerator);
        harness.setTokenRoyalty(tokenId, bob, tokenFeeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, bob);
        /**
         * 250) / 10000 = 2.5 ether
         */
        assertEq(royaltyAmount, 2.5 ether);
    }

    function test_RoyaltyInfo_ZeroSalePrice() public {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 0;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 0);
    }

    function test_RoyaltyInfo_ZeroRoyaltyPercentage() public {
        uint96 feeNumerator = 0; // 0%
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 0);
    }

    function testFuzz_RoyaltyInfo_WithValidFee(uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1000000 ether); // Prevent overflow with reasonable maximum

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR);
    }

    function testFuzz_RoyaltyInfo_WithTokenRoyalty(uint256 tokenId, uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1000000 ether); // Prevent overflow with reasonable maximum

        harness.setTokenRoyalty(tokenId, bob, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, bob);
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR);
    }

    function test_RoyaltyInfo_MultipleTokensDifferentRoyalties() public {
        uint256 token1 = 1;
        uint256 token2 = 2;
        uint256 token3 = 3;
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(alice, 500); // 5%
        harness.setTokenRoyalty(token1, bob, 1000); // 10%
        harness.setTokenRoyalty(token2, charlie, 250); // 2.5%

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(token1, salePrice);
        (address receiver2, uint256 royalty2) = harness.royaltyInfo(token2, salePrice);
        (address receiver3, uint256 royalty3) = harness.royaltyInfo(token3, salePrice);

        assertEq(receiver1, bob);
        assertEq(royalty1, 10 ether);

        assertEq(receiver2, charlie);
        assertEq(royalty2, 2.5 ether);

        assertEq(receiver3, alice);
        assertEq(royalty3, 5 ether);
    }

    function test_RoyaltyInfo_AfterResetTokenRoyalty() public {
        uint256 tokenId = 1;
        uint96 defaultFee = 500; // 5%
        uint96 tokenFee = 1000; // 10%
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(alice, defaultFee);
        harness.setTokenRoyalty(tokenId, bob, tokenFee);

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver1, bob);
        assertEq(royalty1, 10 ether);

        harness.resetTokenRoyalty(tokenId);

        (address receiver2, uint256 royalty2) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver2, alice);
        assertEq(royalty2, 5 ether);
    }

    /**
     * ============================================
     * setDefaultRoyalty Tests
     * ============================================
     */

    function test_SetDefaultRoyalty() public {
        uint96 feeNumerator = 500; // 5%

        harness.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        assertEq(harness.getDefaultRoyaltyReceiver(), royaltyReceiver);
        assertEq(harness.getDefaultRoyaltyFraction(), feeNumerator);
    }

    function test_SetDefaultRoyalty_UpdatesExisting() public {
        harness.setDefaultRoyalty(alice, 500);
        harness.setDefaultRoyalty(bob, 1000);

        assertEq(harness.getDefaultRoyaltyReceiver(), bob);
        assertEq(harness.getDefaultRoyaltyFraction(), 1000);
    }

    function test_SetDefaultRoyalty_ZeroPercentage() public {
        harness.setDefaultRoyalty(royaltyReceiver, 0);

        assertEq(harness.getDefaultRoyaltyReceiver(), royaltyReceiver);
        assertEq(harness.getDefaultRoyaltyFraction(), 0);
    }

    function test_SetDefaultRoyalty_MaxPercentage() public {
        uint96 maxFee = 10000; // 100%

        harness.setDefaultRoyalty(royaltyReceiver, maxFee);

        assertEq(harness.getDefaultRoyaltyReceiver(), royaltyReceiver);
        assertEq(harness.getDefaultRoyaltyFraction(), maxFee);
    }

    function testFuzz_SetDefaultRoyalty(address receiver, uint96 feeNumerator) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(receiver != address(0));

        harness.setDefaultRoyalty(receiver, feeNumerator);

        assertEq(harness.getDefaultRoyaltyReceiver(), receiver);
        assertEq(harness.getDefaultRoyaltyFraction(), feeNumerator);
    }

    function test_RevertWhen_SetDefaultRoyalty_InvalidFee() public {
        uint96 invalidFee = 10001; // More than 100%

        vm.expectRevert(
            abi.encodeWithSelector(LibRoyalty.ERC2981InvalidDefaultRoyalty.selector, invalidFee, FEE_DENOMINATOR)
        );
        harness.setDefaultRoyalty(royaltyReceiver, invalidFee);
    }

    function test_RevertWhen_SetDefaultRoyalty_ZeroReceiver() public {
        vm.expectRevert(abi.encodeWithSelector(LibRoyalty.ERC2981InvalidDefaultRoyaltyReceiver.selector, address(0)));
        harness.setDefaultRoyalty(address(0), 500);
    }

    /**
     * ============================================
     * deleteDefaultRoyalty Tests
     * ============================================
     */

    function test_DeleteDefaultRoyalty() public {
        harness.setDefaultRoyalty(royaltyReceiver, 500);
        harness.deleteDefaultRoyalty();

        assertEq(harness.getDefaultRoyaltyReceiver(), address(0));
        assertEq(harness.getDefaultRoyaltyFraction(), 0);
    }

    function test_DeleteDefaultRoyalty_NoEffectOnTokenRoyalty() public {
        uint256 tokenId = 1;

        harness.setDefaultRoyalty(alice, 500);
        harness.setTokenRoyalty(tokenId, bob, 1000);
        harness.deleteDefaultRoyalty();

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), bob);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 1000);
    }

    function test_DeleteDefaultRoyalty_RoyaltyInfoReturnsZero() public {
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(royaltyReceiver, 500);
        harness.deleteDefaultRoyalty();

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, address(0));
        assertEq(royaltyAmount, 0);
    }

    /**
     * ============================================
     * setTokenRoyalty Tests
     * ============================================
     */

    function test_SetTokenRoyalty() public {
        uint256 tokenId = 1;
        uint96 feeNumerator = 500; // 5%

        harness.setTokenRoyalty(tokenId, royaltyReceiver, feeNumerator);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), royaltyReceiver);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), feeNumerator);
    }

    function test_SetTokenRoyalty_MultipleTokens() public {
        harness.setTokenRoyalty(1, alice, 500);
        harness.setTokenRoyalty(2, bob, 1000);
        harness.setTokenRoyalty(3, charlie, 250);

        assertEq(harness.getTokenRoyaltyReceiver(1), alice);
        assertEq(harness.getTokenRoyaltyFraction(1), 500);

        assertEq(harness.getTokenRoyaltyReceiver(2), bob);
        assertEq(harness.getTokenRoyaltyFraction(2), 1000);

        assertEq(harness.getTokenRoyaltyReceiver(3), charlie);
        assertEq(harness.getTokenRoyaltyFraction(3), 250);
    }

    function test_SetTokenRoyalty_UpdatesExisting() public {
        uint256 tokenId = 1;

        harness.setTokenRoyalty(tokenId, alice, 500);
        harness.setTokenRoyalty(tokenId, bob, 1000);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), bob);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 1000);
    }

    function test_SetTokenRoyalty_ZeroPercentage() public {
        uint256 tokenId = 1;

        harness.setTokenRoyalty(tokenId, royaltyReceiver, 0);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), royaltyReceiver);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 0);
    }

    function test_SetTokenRoyalty_MaxPercentage() public {
        uint256 tokenId = 1;
        uint96 maxFee = 10000; // 100%

        harness.setTokenRoyalty(tokenId, royaltyReceiver, maxFee);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), royaltyReceiver);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), maxFee);
    }

    function testFuzz_SetTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(receiver != address(0));

        harness.setTokenRoyalty(tokenId, receiver, feeNumerator);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), receiver);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), feeNumerator);
    }

    function test_RevertWhen_SetTokenRoyalty_InvalidFee() public {
        uint256 tokenId = 1;
        uint96 invalidFee = 10001; // More than 100%

        vm.expectRevert(
            abi.encodeWithSelector(LibRoyalty.ERC2981InvalidTokenRoyalty.selector, tokenId, invalidFee, FEE_DENOMINATOR)
        );
        harness.setTokenRoyalty(tokenId, royaltyReceiver, invalidFee);
    }

    function test_RevertWhen_SetTokenRoyalty_ZeroReceiver() public {
        uint256 tokenId = 1;

        vm.expectRevert(
            abi.encodeWithSelector(LibRoyalty.ERC2981InvalidTokenRoyaltyReceiver.selector, tokenId, address(0))
        );
        harness.setTokenRoyalty(tokenId, address(0), 500);
    }

    /**
     * ============================================
     * resetTokenRoyalty Tests
     * ============================================
     */

    function test_ResetTokenRoyalty() public {
        uint256 tokenId = 1;

        harness.setTokenRoyalty(tokenId, royaltyReceiver, 500);
        harness.resetTokenRoyalty(tokenId);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), address(0));
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 0);
    }

    function test_ResetTokenRoyalty_FallsBackToDefault() public {
        uint256 tokenId = 1;

        harness.setDefaultRoyalty(alice, 500);
        harness.setTokenRoyalty(tokenId, bob, 1000);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), bob);
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 1000);

        harness.resetTokenRoyalty(tokenId);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), address(0));
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 0);
    }

    function test_ResetTokenRoyalty_MultipleTokens() public {
        harness.setTokenRoyalty(1, alice, 500);
        harness.setTokenRoyalty(2, bob, 1000);
        harness.setTokenRoyalty(3, charlie, 250);

        harness.resetTokenRoyalty(1);
        harness.resetTokenRoyalty(3);

        assertEq(harness.getTokenRoyaltyReceiver(1), address(0));
        assertEq(harness.getTokenRoyaltyReceiver(2), bob);
        assertEq(harness.getTokenRoyaltyReceiver(3), address(0));
    }

    function testFuzz_ResetTokenRoyalty(uint256 tokenId, uint96 feeNumerator) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);

        harness.setTokenRoyalty(tokenId, royaltyReceiver, feeNumerator);
        harness.resetTokenRoyalty(tokenId);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), address(0));
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 0);
    }

    /**
     * ============================================
     * Integration Tests
     * ============================================
     */

    function test_SetDefaultThenTokenThenReset() public {
        uint256 tokenId = 5;
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(alice, 500); // 5%

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver1, alice);
        assertEq(royalty1, 5 ether);

        harness.setTokenRoyalty(tokenId, bob, 1000); // 10%

        (address receiver2, uint256 royalty2) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver2, bob);
        assertEq(royalty2, 10 ether);

        harness.resetTokenRoyalty(tokenId);

        (address receiver3, uint256 royalty3) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver3, alice);
        assertEq(royalty3, 5 ether);
    }

    function test_ComplexRoyaltyFlow() public {
        uint256 token1 = 1;
        uint256 token2 = 2;
        uint256 token3 = 3;
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(alice, 500); // 5% default

        harness.setTokenRoyalty(token1, bob, 1000); // 10%
        harness.setTokenRoyalty(token2, charlie, 250); // 2.5%

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(token1, salePrice);
        (address receiver2, uint256 royalty2) = harness.royaltyInfo(token2, salePrice);
        (address receiver3, uint256 royalty3) = harness.royaltyInfo(token3, salePrice);

        assertEq(receiver1, bob);
        assertEq(royalty1, 10 ether);

        assertEq(receiver2, charlie);
        assertEq(royalty2, 2.5 ether);

        assertEq(receiver3, alice);
        assertEq(royalty3, 5 ether);

        harness.deleteDefaultRoyalty();

        (receiver3, royalty3) = harness.royaltyInfo(token3, salePrice);
        assertEq(receiver3, address(0));
        assertEq(royalty3, 0);
    }
}
