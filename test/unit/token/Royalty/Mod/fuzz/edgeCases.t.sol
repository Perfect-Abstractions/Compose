// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyMod_Base_Test} from "test/unit/token/Royalty/RoyaltyModBase.t.sol";

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  EdgeCases
 */
contract EdgeCases_RoyaltyMod_Unit_Test is RoyaltyMod_Base_Test {
    function test_RoyaltyInfo_FractionalRoyalty() external {
        uint96 feeNumerator = 1; // 0.01%
        uint256 salePrice = 100_000 ether;
        uint256 expectedRoyalty = 10 ether;

        harness.setDefaultRoyalty(users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, expectedRoyalty, "royaltyAmount");
    }

    function test_RoyaltyInfo_LargeSalePrice() external {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 1_000_000_000 ether;

        harness.setDefaultRoyalty(users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function test_RoyaltyInfo_TokenIdZero() external {
        uint256 tokenId = 0;
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;

        harness.setTokenRoyalty(tokenId, users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 5 ether, "royaltyAmount");
    }

    function test_RoyaltyInfo_TokenIdMax() external {
        uint256 tokenId = type(uint256).max;
        uint96 feeNumerator = 1_000; // 10%
        uint256 salePrice = 50 ether;

        harness.setTokenRoyalty(tokenId, users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 5 ether, "royaltyAmount");
    }
}
