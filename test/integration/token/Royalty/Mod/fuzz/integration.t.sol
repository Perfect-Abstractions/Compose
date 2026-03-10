// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyMod_Base_Test} from "test/unit/token/Royalty/RoyaltyModBase.t.sol";

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  Integration (Mod)
 */
contract Integration_RoyaltyMod_Integration_Test is RoyaltyMod_Base_Test {
    function test_DefaultThenTokenThenReset_Sequence() external {
        uint256 tokenId = 5;
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(users.alice, 500);

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver1, users.alice, "receiver1");
        assertEq(royalty1, 5 ether, "royalty1");

        harness.setTokenRoyalty(tokenId, users.bob, 1_000);

        (address receiver2, uint256 royalty2) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver2, users.bob, "receiver2");
        assertEq(royalty2, 10 ether, "royalty2");

        harness.resetTokenRoyalty(tokenId);

        (address receiver3, uint256 royalty3) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver3, users.alice, "receiver3");
        assertEq(royalty3, 5 ether, "royalty3");
    }

    function test_DefaultAndMultipleTokensThenDeleteDefault_Behavior() external {
        uint256 token1 = 1;
        uint256 token2 = 2;
        uint256 token3 = 3;
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(users.alice, 500);
        harness.setTokenRoyalty(token1, users.bob, 1_000);
        harness.setTokenRoyalty(token2, users.charlee, 250);

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(token1, salePrice);
        (address receiver2, uint256 royalty2) = harness.royaltyInfo(token2, salePrice);
        (address receiver3, uint256 royalty3) = harness.royaltyInfo(token3, salePrice);

        assertEq(receiver1, users.bob, "receiver1");
        assertEq(royalty1, 10 ether, "royalty1");

        assertEq(receiver2, users.charlee, "receiver2");
        assertEq(royalty2, 2.5 ether, "royalty2");

        assertEq(receiver3, users.alice, "receiver3");
        assertEq(royalty3, 5 ether, "royalty3");

        harness.deleteDefaultRoyalty();

        // token-specific royalties remain unchanged
        (receiver1, royalty1) = harness.royaltyInfo(token1, salePrice);
        (receiver2, royalty2) = harness.royaltyInfo(token2, salePrice);
        assertEq(receiver1, users.bob, "receiver1 after delete");
        assertEq(royalty1, 10 ether, "royalty1 after delete");
        assertEq(receiver2, users.charlee, "receiver2 after delete");
        assertEq(royalty2, 2.5 ether, "royalty2 after delete");

        (receiver3, royalty3) = harness.royaltyInfo(token3, salePrice);
        assertEq(receiver3, ADDRESS_ZERO, "receiver3 after delete");
        assertEq(royalty3, 0, "royalty3 after delete");
    }
}
