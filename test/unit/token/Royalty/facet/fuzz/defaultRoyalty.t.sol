// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {RoyaltyFacet_Base_Test} from "test/unit/token/Royalty/RoyaltyFacetBase.t.sol";

/**
 *  @dev BTT spec: test/trees/Royalty.tree
 *
 *  DefaultRoyalty
 */
contract DefaultRoyalty_RoyaltyFacet_Fuzz_Unit_Test is RoyaltyFacet_Base_Test {
    function testFuzz_SetDefaultRoyalty_VisibleThroughRoyaltyInfo(
        address receiver,
        uint96 feeNumerator,
        uint256 salePrice
    ) external {
        vm.assume(receiver != ADDRESS_ZERO);
        vm.assume(feeNumerator <= FEE_DENOMINATOR);
        vm.assume(salePrice <= 1_000_000 ether);

        facet.setDefaultRoyalty(receiver, feeNumerator);

        (address royaltyReceiverResult, uint256 royaltyAmount) = facet.royaltyInfo(1, salePrice);

        assertEq(royaltyReceiverResult, receiver, "receiver");
        assertEq(royaltyAmount, (salePrice * feeNumerator) / FEE_DENOMINATOR, "royaltyAmount");
    }

    function test_SetDefaultRoyalty_UpdatesExisting_ThroughRoyaltyInfo() external {
        facet.setDefaultRoyalty(users.alice, 500);
        facet.setDefaultRoyalty(users.bob, 1_000);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, 100 ether);

        assertEq(receiver, users.bob, "receiver");
        assertEq(royaltyAmount, 10 ether, "royaltyAmount");
    }

    function test_SetDefaultRoyalty_ZeroFee_KeepsReceiver_ThroughRoyaltyInfo() external {
        facet.setDefaultRoyalty(users.receiver, 0);

        (address receiver, uint256 royaltyAmount) = facet.royaltyInfo(1, 100 ether);

        assertEq(receiver, users.receiver, "receiver");
        assertEq(royaltyAmount, 0, "royaltyAmount");
    }
}
