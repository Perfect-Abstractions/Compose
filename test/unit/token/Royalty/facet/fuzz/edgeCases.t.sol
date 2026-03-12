// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyFacet_Base_Test} from "test/unit/token/Royalty/RoyaltyFacetBase.t.sol";

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  EdgeCases
 */
contract EdgeCases_RoyaltyFacet_Unit_Test is RoyaltyFacet_Base_Test {
    function test_RoyaltyInfo_FractionalRoyalty_ThroughRoyaltyInfo() external {
        uint96 feeNumerator = 1; // 0.01%
        uint256 salePrice = 100_000 ether;
        uint256 expectedRoyalty = 10 ether;

        facet.setDefaultRoyalty(users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, expectedRoyalty, "royaltyAmount");
    }

    function test_RoyaltyInfo_LargeSalePrice_ThroughRoyaltyInfo() external {
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 1_000_000_000 ether;

        facet.setDefaultRoyalty(users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function test_RoyaltyInfo_TokenIdZero_ThroughRoyaltyInfo() external {
        uint256 tokenId = 0;
        uint96 feeNumerator = 500; // 5%
        uint256 salePrice = 100 ether;

        facet.setTokenRoyalty(tokenId, users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 5 ether, "royaltyAmount");
    }

    function test_RoyaltyInfo_TokenIdMax_ThroughRoyaltyInfo() external {
        uint256 tokenId = type(uint256).max;
        uint96 feeNumerator = 1_000; // 10%
        uint256 salePrice = 50 ether;

        facet.setTokenRoyalty(tokenId, users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 5 ether, "royaltyAmount");
    }
}
