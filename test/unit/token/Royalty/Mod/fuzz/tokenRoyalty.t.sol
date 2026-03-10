// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyMod_Base_Test} from "test/unit/token/Royalty/RoyaltyModBase.t.sol";

import "src/token/Royalty/RoyaltyMod.sol" as RoyaltyMod;

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  TokenRoyalty
 */
contract TokenRoyalty_RoyaltyMod_Fuzz_Unit_Test is RoyaltyMod_Base_Test {
    /* SetTokenRoyalty */

    function testFuzz_SetTokenRoyalty_SetsReceiverAndFraction(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external {
        vm.assume(receiver != ADDRESS_ZERO);
        vm.assume(feeNumerator <= FEE_DENOMINATOR);

        harness.setTokenRoyalty(tokenId, receiver, feeNumerator);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), receiver, "token receiver");
        assertEq(harness.getTokenRoyaltyFraction(tokenId), feeNumerator, "token fraction");
    }

    function test_SetTokenRoyalty_MultipleTokens_IndependentState() external {
        harness.setTokenRoyalty(1, users.alice, 500);
        harness.setTokenRoyalty(2, users.bob, 1_000);
        harness.setTokenRoyalty(3, users.charlee, 250);

        assertEq(harness.getTokenRoyaltyReceiver(1), users.alice, "token1 receiver");
        assertEq(harness.getTokenRoyaltyFraction(1), 500, "token1 fraction");

        assertEq(harness.getTokenRoyaltyReceiver(2), users.bob, "token2 receiver");
        assertEq(harness.getTokenRoyaltyFraction(2), 1_000, "token2 fraction");

        assertEq(harness.getTokenRoyaltyReceiver(3), users.charlee, "token3 receiver");
        assertEq(harness.getTokenRoyaltyFraction(3), 250, "token3 fraction");
    }

    function test_SetTokenRoyalty_UpdatesExisting() external {
        uint256 tokenId = 1;

        harness.setTokenRoyalty(tokenId, users.alice, 500);
        harness.setTokenRoyalty(tokenId, users.bob, 1_000);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), users.bob, "token receiver");
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 1_000, "token fraction");
    }

    function test_SetTokenRoyalty_ZeroFee_KeepsReceiver() external {
        uint256 tokenId = 1;

        harness.setTokenRoyalty(tokenId, users.receiver, 0);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), users.receiver, "token receiver");
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 0, "token fraction");
    }

    function test_RevertWhen_SetTokenRoyalty_FeeAboveDenominator() external {
        uint256 tokenId = 1;
        uint96 invalidFee = uint96(FEE_DENOMINATOR + 1);

        vm.expectRevert(
            abi.encodeWithSelector(RoyaltyMod.ERC2981InvalidTokenRoyalty.selector, tokenId, invalidFee, FEE_DENOMINATOR)
        );
        harness.setTokenRoyalty(tokenId, users.receiver, invalidFee);
    }

    function test_RevertWhen_SetTokenRoyalty_ZeroReceiver() external {
        uint256 tokenId = 1;

        vm.expectRevert(
            abi.encodeWithSelector(RoyaltyMod.ERC2981InvalidTokenRoyaltyReceiver.selector, tokenId, ADDRESS_ZERO)
        );
        harness.setTokenRoyalty(tokenId, ADDRESS_ZERO, 500);
    }

    /* ResetTokenRoyalty */

    function testFuzz_ResetTokenRoyalty_NoDefault_ClearsTokenRoyalty(
        uint256 tokenId,
        uint96 feeNumerator
    ) external {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);

        harness.setTokenRoyalty(tokenId, users.receiver, feeNumerator);
        harness.resetTokenRoyalty(tokenId);

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), ADDRESS_ZERO, "token receiver");
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 0, "token fraction");
    }

    function test_ResetTokenRoyalty_WithDefault_FallsBackToDefault() external {
        uint256 tokenId = 1;
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(users.alice, 500);
        harness.setTokenRoyalty(tokenId, users.bob, 1_000);

        (address receiver1, uint256 royalty1) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver1, users.bob, "receiver1");
        assertEq(royalty1, 10 ether, "royalty1");

        harness.resetTokenRoyalty(tokenId);

        (address receiver2, uint256 royalty2) = harness.royaltyInfo(tokenId, salePrice);
        assertEq(receiver2, users.alice, "receiver2");
        assertEq(royalty2, 5 ether, "royalty2");
    }

    function test_ResetTokenRoyalty_MultipleTokens_PartialReset() external {
        harness.setTokenRoyalty(1, users.alice, 500);
        harness.setTokenRoyalty(2, users.bob, 1_000);
        harness.setTokenRoyalty(3, users.charlee, 250);

        harness.resetTokenRoyalty(1);
        harness.resetTokenRoyalty(3);

        assertEq(harness.getTokenRoyaltyReceiver(1), ADDRESS_ZERO, "token1 receiver");
        assertEq(harness.getTokenRoyaltyFraction(1), 0, "token1 fraction");

        assertEq(harness.getTokenRoyaltyReceiver(2), users.bob, "token2 receiver");
        assertEq(harness.getTokenRoyaltyFraction(2), 1_000, "token2 fraction");

        assertEq(harness.getTokenRoyaltyReceiver(3), ADDRESS_ZERO, "token3 receiver");
        assertEq(harness.getTokenRoyaltyFraction(3), 0, "token3 fraction");
    }
}
