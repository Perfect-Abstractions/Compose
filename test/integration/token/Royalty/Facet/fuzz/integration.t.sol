// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyFacet_Base_Test} from "test/unit/token/Royalty/RoyaltyFacetBase.t.sol";

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  Integration (Facet)
 */
contract Integration_RoyaltyFacet_Integration_Test is RoyaltyFacet_Base_Test {
    function test_DefaultThenTokenThenReset_ThroughRoyaltyInfo() external {
        uint256 tokenId = 5;
        uint256 salePrice = 100 ether;

        facet.setDefaultRoyalty(users.alice, 500);

        (address receiver1, uint256 royalty1) = facet.royaltyInfo(tokenId, salePrice);
        assertEq(receiver1, users.alice, "receiver1");
        assertEq(royalty1, 5 ether, "royalty1");

        facet.setTokenRoyalty(tokenId, users.bob, 1_000);

        (address receiver2, uint256 royalty2) = facet.royaltyInfo(tokenId, salePrice);
        assertEq(receiver2, users.bob, "receiver2");
        assertEq(royalty2, 10 ether, "royalty2");

        facet.setTokenRoyalty(tokenId, ADDRESS_ZERO, 0);

        (address receiver3, uint256 royalty3) = facet.royaltyInfo(tokenId, salePrice);
        assertEq(receiver3, users.alice, "receiver3");
        assertEq(royalty3, 5 ether, "royalty3");
    }

    function test_DefaultAndMultipleTokensThenDeleteDefault_ThroughRoyaltyInfo() external {
        uint256 token1 = 1;
        uint256 token2 = 2;
        uint256 token3 = 3;
        uint256 salePrice = 100 ether;

        facet.setDefaultRoyalty(users.alice, 500);
        facet.setTokenRoyalty(token1, users.bob, 1_000);
        facet.setTokenRoyalty(token2, users.charlee, 250);

        (address receiver1, uint256 royalty1) = facet.royaltyInfo(token1, salePrice);
        (address receiver2, uint256 royalty2) = facet.royaltyInfo(token2, salePrice);
        (address receiver3, uint256 royalty3) = facet.royaltyInfo(token3, salePrice);

        assertEq(receiver1, users.bob, "receiver1");
        assertEq(royalty1, 10 ether, "royalty1");

        assertEq(receiver2, users.charlee, "receiver2");
        assertEq(royalty2, 2.5 ether, "royalty2");

        assertEq(receiver3, users.alice, "receiver3");
        assertEq(royalty3, 5 ether, "royalty3");

        facet.setDefaultRoyalty(ADDRESS_ZERO, 0);

        (receiver3, royalty3) = facet.royaltyInfo(token3, salePrice);
        assertEq(receiver3, ADDRESS_ZERO, "receiver3 after delete");
        assertEq(royalty3, 0, "royalty3 after delete");
    }
}
