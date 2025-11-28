// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {RoyaltyFacet} from "../../../src/token/Royalty/RoyaltyFacet.sol";
import {RoyaltyFacetHarness} from "./harnesses/RoyaltyFacetHarness.sol";

contract RoyaltyFacetTest is Test {
    RoyaltyFacetHarness public facet;

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

        facet = new RoyaltyFacetHarness();
    }

    /**
     * ============================================
     * Helper Functions
     * ============================================
     */

    /**
     * @notice Helper to set default royalty
     */
    function _setDefaultRoyalty(address _receiver, uint96 _feeNumerator) internal {
        facet.setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @notice Helper to set token royalty
     */
    function _setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) internal {
        facet.setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /**
     * ============================================
     * royaltyInfo Tests
     * ============================================
     */

    function test_RoyaltyInfo_NoRoyaltySet() public view {
        uint256 tokenId = 1;
        uint256 salePrice = 1 ether;

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, address(0));
        assertEq(royaltyAmount, 0);
    }

    function test_RoyaltyInfo_DefaultRoyaltyOnly() public {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, salePrice * feeNumerator / FEE_DENOMINATOR);
    }

    function test_RoyaltyInfo_5PercentRoyalty() public {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;
        uint256 expectedRoyalty = 5 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_10PercentRoyalty() public {
        uint96 feeNumerator = 1000; // 10%
        uint256 salePrice = 50 ether;
        uint256 expectedRoyalty = 5 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_50PercentRoyalty() public {
        uint96 feeNumerator = 5000; // 50%
        uint256 salePrice = 10 ether;
        uint256 expectedRoyalty = 5 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_100PercentRoyalty() public {
        uint96 feeNumerator = 10000; // 100%
        uint256 salePrice = 1 ether;
        uint256 expectedRoyalty = 1 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_TokenSpecificRoyalty() public {
        uint256 tokenId = 5;
        uint96 tokenFeeNumerator = 750; // 7.5%
        uint256 salePrice = 100 ether;

        _setTokenRoyalty(tokenId, bob, tokenFeeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, bob);
        assertEq(royaltyAmount, 7.5 ether);
    }

    function test_RoyaltyInfo_TokenSpecificOverridesDefault() public {
        uint256 tokenId = 10;
        uint96 defaultFeeNumerator = 1000; // 10%
        uint96 tokenFeeNumerator = 250; // 2.5%
        uint256 salePrice = 100 ether;

        _setDefaultRoyalty(alice, defaultFeeNumerator);
        _setTokenRoyalty(tokenId, bob, tokenFeeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, bob);
        assertEq(royaltyAmount, 2.5 ether);
    }

    function test_RoyaltyInfo_ZeroSalePrice() public {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 0;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 0);
    }

    function test_RoyaltyInfo_ZeroRoyaltyPercentage() public {
        uint96 feeNumerator = 0; // 0%
        uint256 salePrice = 100 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 0);
    }

    function testFuzz_RoyaltyInfo_WithValidFee(uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1000000 ether); // Prevent overflow with reasonable maximum

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR);
    }

    function testFuzz_RoyaltyInfo_WithTokenRoyalty(uint256 tokenId, uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1000000 ether); // Prevent overflow with reasonable maximum

        _setTokenRoyalty(tokenId, bob, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, bob);
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR);
    }

    function test_RoyaltyInfo_MultipleTokensDifferentRoyalties() public {
        uint256 token1 = 1;
        uint256 token2 = 2;
        uint256 token3 = 3;
        uint256 salePrice = 100 ether;

        _setDefaultRoyalty(alice, 500); // 5%
        _setTokenRoyalty(token1, bob, 1000); // 10%
        _setTokenRoyalty(token2, charlie, 250); // 2.5%

        (address receiver1, uint256 royalty1) = facet.royaltyInfo(token1, salePrice);
        (address receiver2, uint256 royalty2) = facet.royaltyInfo(token2, salePrice);
        (address receiver3, uint256 royalty3) = facet.royaltyInfo(token3, salePrice);

        assertEq(receiver1, bob);
        assertEq(royalty1, 10 ether);

        assertEq(receiver2, charlie);
        assertEq(royalty2, 2.5 ether);

        assertEq(receiver3, alice);
        assertEq(royalty3, 5 ether);
    }

    function test_RoyaltyInfo_FractionalRoyalty() public {
        uint96 feeNumerator = 1; // 0.01%
        uint256 salePrice = 100000 ether;
        uint256 expectedRoyalty = 10 ether;

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_RoyaltyInfo_LargeSalePrice() public {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 1000000000 ether; // Large but safe value

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, salePrice * feeNumerator / FEE_DENOMINATOR);
    }

    function test_RoyaltyInfo_VariousFeePercentages() public {
        uint256 salePrice = 1 ether;

        uint96[] memory fees = new uint96[](6);
        fees[0] = 1; // 0.01%
        fees[1] = 25; // 0.25%
        fees[2] = 100; // 1%
        fees[3] = 250; // 2.5%
        fees[4] = 500; // 5%
        fees[5] = 750; // 7.5%

        uint256[] memory expectedRoyalties = new uint256[](6);
        expectedRoyalties[0] = 0.0001 ether;
        expectedRoyalties[1] = 0.0025 ether;
        expectedRoyalties[2] = 0.01 ether;
        expectedRoyalties[3] = 0.025 ether;
        expectedRoyalties[4] = 0.05 ether;
        expectedRoyalties[5] = 0.075 ether;

        for (uint256 i = 0; i < fees.length; i++) {
            _setDefaultRoyalty(royaltyReceiver, fees[i]);
            (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);
            assertEq(receiver, royaltyReceiver);
            assertEq(royaltyAmount, expectedRoyalties[i]);
        }
    }

    function test_RoyaltyInfo_SmallTokenId() public {
        uint256 tokenId = 0;
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;

        _setTokenRoyalty(tokenId, royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 5 ether);
    }

    function test_RoyaltyInfo_VeryLargeTokenId() public {
        uint256 tokenId = type(uint256).max;
        uint96 feeNumerator = 1000; // 10%
        uint256 salePrice = 50 ether;

        _setTokenRoyalty(tokenId, royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 5 ether);
    }

    function test_RoyaltyInfo_FallsBackWhenTokenRoyaltyNotSet() public {
        uint256 tokenId = 999;
        uint96 defaultFee = 750; // 7.5%
        uint256 salePrice = 100 ether;

        _setDefaultRoyalty(royaltyReceiver, defaultFee);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 7.5 ether);
    }

    function test_RoyaltyInfo_DefaultRoyaltyAddress() public {
        uint256 salePrice = 100 ether;
        uint96 feeNumerator = 500; // 5%

        _setDefaultRoyalty(alice, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, alice);
        assertEq(royaltyAmount, 5 ether);
    }

    function test_RoyaltyInfo_ZeroAddressReceiverReturnsZero() public view {
        /**
         * Set up a token royalty with non-zero fee but zero address
         * This simulates the edge case
         */
        uint256 tokenId = 5;
        uint256 salePrice = 100 ether;

        /**
         * No royalty set - should return zero
         */
        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);
        assertEq(receiver, address(0));
        assertEq(royaltyAmount, 0);
    }

    /**
     * ============================================
     * Storage Consistency Tests
     * ============================================
     */

    function test_StorageSlot_Consistency() public {
        uint96 feeNumerator = 500; // 5%

        facet.setDefaultRoyalty(royaltyReceiver, feeNumerator);

        /**
         * Read back through facet function to verify
         */
        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(999, 100 ether);
        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, 5 ether);
    }

    function test_StorageSlot_TokenRoyaltyConsistency() public {
        uint256 tokenId = 42;
        uint96 feeNumerator = 1000; // 10%

        facet.setTokenRoyalty(tokenId, bob, feeNumerator);

        /**
         * Read back through facet function to verify
         */
        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, 100 ether);
        assertEq(receiver, bob);
        assertEq(royaltyAmount, 10 ether);
    }

    /**
     * ============================================
     * Edge Cases
     * ============================================
     */

    function test_RoyaltyInfo_WithMaximumValues() public {
        uint96 maxFee = 10000; // 100%
        uint256 maxSalePrice = 1000000000 ether; // Large but safe value

        _setDefaultRoyalty(royaltyReceiver, maxFee);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, maxSalePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, maxSalePrice);
    }

    function test_RoyaltyInfo_VariousTokenIds() public {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;

        _setTokenRoyalty(1, alice, feeNumerator);
        _setTokenRoyalty(100, bob, feeNumerator);
        _setTokenRoyalty(999999, charlie, feeNumerator);

        (address receiver1, uint256 royalty1) = facet.royaltyInfo(1, salePrice);
        (address receiver2, uint256 royalty2) = facet.royaltyInfo(100, salePrice);
        (address receiver3, uint256 royalty3) = facet.royaltyInfo(999999, salePrice);

        assertEq(receiver1, alice);
        assertEq(royalty1, 5 ether);

        assertEq(receiver2, bob);
        assertEq(royalty2, 5 ether);

        assertEq(receiver3, charlie);
        assertEq(royalty3, 5 ether);
    }

    function test_RoyaltyInfo_MinimalRoyaltyFee() public {
        uint96 feeNumerator = 1; // 0.01%
        uint256 salePrice = 1 ether;
        uint256 expectedRoyalty = 0.0001 ether; // 0.0001 ETH

        _setDefaultRoyalty(royaltyReceiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, royaltyReceiver);
        assertEq(royaltyAmount, expectedRoyalty);
    }

    function test_ComplexScenario_MultipleTokensAndDefaults() public {
        /**
         * Set up complex royalty structure
         */
        _setDefaultRoyalty(alice, 500); // 5% default

        _setTokenRoyalty(1, bob, 1000); // Token 1: 10%
        _setTokenRoyalty(2, charlie, 250); // Token 2: 2.5%

        uint256 salePrice = 100 ether;

        /**
         * Token 1 should use token-specific
         */
        (address receiver1, uint256 royalty1) = facet.royaltyInfo(1, salePrice);
        assertEq(receiver1, bob);
        assertEq(royalty1, 10 ether);

        /**
         * Token 2 should use token-specific
         */
        (address receiver2, uint256 royalty2) = facet.royaltyInfo(2, salePrice);
        assertEq(receiver2, charlie);
        assertEq(royalty2, 2.5 ether);

        /**
         * Token 999 should use default
         */
        (address receiver3, uint256 royalty3) = facet.royaltyInfo(999, salePrice);
        assertEq(receiver3, alice);
        assertEq(royalty3, 5 ether);
    }
}
