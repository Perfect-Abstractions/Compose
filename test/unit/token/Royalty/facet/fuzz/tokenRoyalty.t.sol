// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyFacet_Base_Test} from "test/unit/token/Royalty/RoyaltyFacetBase.t.sol";

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  TokenRoyalty
 */
contract TokenRoyalty_RoyaltyFacet_Fuzz_Unit_Test is RoyaltyFacet_Base_Test {
    function testFuzz_SetTokenRoyalty_VisibleThroughRoyaltyInfo(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator,
        uint256 salePrice
    ) external {
        vm.assume(receiver != ADDRESS_ZERO);
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1_000_000 ether);

        facet.setTokenRoyalty(tokenId, receiver, feeNumerator);

        (address royaltyReceiverResult, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, salePrice);

        assertEq(royaltyReceiverResult, receiver, "receiver");
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function test_SetTokenRoyalty_MultipleTokens_IndependentState_ThroughRoyaltyInfo() external {
        facet.setTokenRoyalty(1, users.alice, 500);
        facet.setTokenRoyalty(2, users.bob, 1_000);
        facet.setTokenRoyalty(3, users.charlee, 250);

        (address receiver1, uint256 royalty1) = facet.royaltyInfo(1, 100 ether);
        (address receiver2, uint256 royalty2) = facet.royaltyInfo(2, 100 ether);
        (address receiver3, uint256 royalty3) = facet.royaltyInfo(3, 100 ether);

        assertEq(receiver1, users.alice, "receiver1");
        assertEq(royalty1, 5 ether, "royalty1");

        assertEq(receiver2, users.bob, "receiver2");
        assertEq(royalty2, 10 ether, "royalty2");

        assertEq(receiver3, users.charlee, "receiver3");
        assertEq(royalty3, 2.5 ether, "royalty3");
    }

    function test_SetTokenRoyalty_UpdatesExisting_ThroughRoyaltyInfo() external {
        uint256 tokenId = 1;

        facet.setTokenRoyalty(tokenId, users.alice, 500);
        facet.setTokenRoyalty(tokenId, users.bob, 1_000);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, 100 ether);

        assertEq(receiver, users.bob, "receiver");
        assertEq(royaltyAmount, 10 ether, "royaltyAmount");
    }

    function test_SetTokenRoyalty_ZeroFee_KeepsReceiver_ThroughRoyaltyInfo() external {
        uint256 tokenId = 1;

        facet.setTokenRoyalty(tokenId, users.receiver, 0);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(tokenId, 100 ether);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 0, "royaltyAmount");
    }
}
