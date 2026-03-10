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
 *  DefaultRoyalty
 */
contract DefaultRoyalty_RoyaltyMod_Fuzz_Unit_Test is RoyaltyMod_Base_Test {
    /* SetDefaultRoyalty */

    function testFuzz_SetDefaultRoyalty_SetsReceiverAndFraction(address receiver, uint96 feeNumerator) external {
        vm.assume(receiver != ADDRESS_ZERO);
        vm.assume(feeNumerator <= FEE_DENOMINATOR);

        harness.setDefaultRoyalty(receiver, feeNumerator);

        assertEq(harness.getDefaultRoyaltyReceiver(), receiver, "default receiver");
        assertEq(harness.getDefaultRoyaltyFraction(), feeNumerator, "default fraction");
    }

    function test_SetDefaultRoyalty_UpdatesExisting() external {
        harness.setDefaultRoyalty(users.alice, 500);
        harness.setDefaultRoyalty(users.bob, 1_000);

        assertEq(harness.getDefaultRoyaltyReceiver(), users.bob, "default receiver");
        assertEq(harness.getDefaultRoyaltyFraction(), 1_000, "default fraction");
    }

    function test_SetDefaultRoyalty_ZeroFee_KeepsReceiver() external {
        harness.setDefaultRoyalty(users.receiver, 0);

        assertEq(harness.getDefaultRoyaltyReceiver(), users.receiver, "default receiver");
        assertEq(harness.getDefaultRoyaltyFraction(), 0, "default fraction");
    }

    function test_RevertWhen_SetDefaultRoyalty_FeeAboveDenominator() external {
        uint96 invalidFee = uint96(FEE_DENOMINATOR + 1);

        vm.expectRevert(
            abi.encodeWithSelector(RoyaltyMod.ERC2981InvalidDefaultRoyalty.selector, invalidFee, FEE_DENOMINATOR)
        );
        harness.setDefaultRoyalty(users.receiver, invalidFee);
    }

    function test_RevertWhen_SetDefaultRoyalty_ZeroReceiver() external {
        vm.expectRevert(abi.encodeWithSelector(RoyaltyMod.ERC2981InvalidDefaultRoyaltyReceiver.selector, ADDRESS_ZERO));
        harness.setDefaultRoyalty(ADDRESS_ZERO, 500);
    }

    /* DeleteDefaultRoyalty */

    function testFuzz_DeleteDefaultRoyalty_ClearsStorage(uint96 feeNumerator) external {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);

        harness.setDefaultRoyalty(users.receiver, feeNumerator);
        harness.deleteDefaultRoyalty();

        assertEq(harness.getDefaultRoyaltyReceiver(), ADDRESS_ZERO, "default receiver");
        assertEq(harness.getDefaultRoyaltyFraction(), 0, "default fraction");
    }

    function test_DeleteDefaultRoyalty_NoTokenRoyalty_RoyaltyInfoZero() external {
        uint256 salePrice = 100 ether;

        harness.setDefaultRoyalty(users.receiver, 500);
        harness.deleteDefaultRoyalty();

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, ADDRESS_ZERO, "receiver");
        assertEq(royaltyAmount, 0, "royaltyAmount");
    }

    function test_DeleteDefaultRoyalty_WithTokenRoyalty_TokenRoyaltyUnchanged() external {
        uint256 tokenId = 1;

        harness.setDefaultRoyalty(users.alice, 500);
        harness.setTokenRoyalty(tokenId, users.bob, 1_000);
        harness.deleteDefaultRoyalty();

        assertEq(harness.getTokenRoyaltyReceiver(tokenId), users.bob, "token receiver");
        assertEq(harness.getTokenRoyaltyFraction(tokenId), 1_000, "token fraction");
    }
}
