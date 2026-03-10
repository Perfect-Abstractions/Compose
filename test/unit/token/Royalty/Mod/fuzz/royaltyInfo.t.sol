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
 *  RoyaltyInfo
 */
contract RoyaltyInfo_RoyaltyMod_Fuzz_Unit_Test is RoyaltyMod_Base_Test {
    function testFuzz_RoyaltyInfo_NoRoyaltySet(uint256 tokenId, uint256 salePrice) external view {
        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, address(0), "receiver");
        assertEq(royaltyAmount, 0, "royaltyAmount");
    }

    function testFuzz_RoyaltyInfo_OnlyDefaultRoyalty(uint96 feeNumerator, uint256 salePrice) external {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1_000_000 ether);

        harness.setDefaultRoyalty(users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function testFuzz_RoyaltyInfo_OnlyTokenRoyalty(
        uint256 tokenId,
        uint96 feeNumerator,
        uint256 salePrice
    ) external {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1_000_000 ether);

        harness.setTokenRoyalty(tokenId, users.bob, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, users.bob, "receiver");
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function testFuzz_RoyaltyInfo_DefaultAndTokenRoyalty_TokenOverridesDefault(
        uint256 tokenId,
        uint96 defaultFee,
        uint96 tokenFee,
        uint256 salePrice
    ) external {
        vm.assume(defaultFee <= FEE_DENOMINATOR);
        vm.assume(tokenFee <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1_000_000 ether);

        harness.setDefaultRoyalty(users.alice, defaultFee);
        harness.setTokenRoyalty(tokenId, users.bob, tokenFee);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, salePrice);

        assertEq(receiver, users.bob, "receiver");
        assertEq(royaltyAmount, (salePrice * tokenFee) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function testFuzz_RoyaltyInfo_ZeroSalePrice_PreservesReceiver(uint96 feeNumerator, uint256 tokenId) external {
        vm.assume(feeNumerator <= FEE_DENOMINATOR);

        harness.setDefaultRoyalty(users.receiver, feeNumerator);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(tokenId, 0);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 0, "royaltyAmount");
    }

    function testFuzz_RoyaltyInfo_ZeroFee_PreservesReceiver(uint256 salePrice) external {
        vm.assume(salePrice <= 1_000_000 ether);

        harness.setDefaultRoyalty(users.receiver, 0);

        (address receiver, uint256 royaltyAmount) = harness.royaltyInfo(1, salePrice);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 0, "royaltyAmount");
    }
}

