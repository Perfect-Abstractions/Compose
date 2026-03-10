// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155BurnFacet_Base_Test} from "test/unit/token/ERC1155/Burn/ERC1155BurnFacetBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155BurnFacet} from "src/token/ERC1155/Burn/ERC1155BurnFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract Burn_ERC1155BurnFacet_Fuzz_Test is ERC1155BurnFacet_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_Burn_WhenFromIsZeroAddress(uint256 id, uint256 value) external {
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155BurnFacet.ERC1155InvalidSender.selector, address(0)));
        facet.burn(address(0), id, value);
    }

    function testFuzz_ShouldRevert_Burn_WhenNotApprovedAndNotOwner(
        address from,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(from != users.bob);
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, from, value);
        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155BurnFacet.ERC1155MissingApprovalForAll.selector, users.bob, from)
        );
        facet.burn(from, id, value);
    }

    function testFuzz_ShouldRevert_Burn_WhenInsufficientBalance(
        address from,
        uint256 id,
        uint256 balance,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(balance < type(uint256).max);
        value = bound(value, balance + 1, type(uint256).max);
        address(facet).setBalanceOf(id, from, balance);
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155BurnFacet.ERC1155InsufficientBalance.selector,
                from,
                balance,
                value,
                id
            )
        );
        facet.burn(from, id, value);
    }

    function testFuzz_ShouldDecrementBalance_Burn_WhenPreconditionsHold(
        address from,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, from, value);
        vm.stopPrank();
        vm.prank(from);
        facet.burn(from, id, value);
        assertEq(address(facet).balanceOf(id, from), 0, "balance");
    }

    function testFuzz_ShouldDecrementBalance_Burn_WhenApprovedOperator(
        address from,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, from, value);
        address(facet).setApprovedForAll(from, users.alice, true);
        vm.stopPrank();
        vm.prank(users.alice);
        facet.burn(from, id, value);
        assertEq(address(facet).balanceOf(id, from), 0, "balance");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC1155BurnFacet.burn.selector,
            ERC1155BurnFacet.burnBatch.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
