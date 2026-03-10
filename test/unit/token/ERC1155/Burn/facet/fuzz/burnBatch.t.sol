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
contract BurnBatch_ERC1155BurnFacet_Fuzz_Test is ERC1155BurnFacet_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_BurnBatch_WhenFromIsZeroAddress(
        uint256 id,
        uint256 value
    ) external {
        vm.stopPrank();
        vm.prank(users.alice);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = id;
        values[0] = value;
        vm.expectRevert(abi.encodeWithSelector(ERC1155BurnFacet.ERC1155InvalidSender.selector, address(0)));
        facet.burnBatch(address(0), ids, values);
    }

    function testFuzz_ShouldRevert_BurnBatch_WhenIdsLengthNotEqualToValuesLength(
        address from,
        uint256 idsLen,
        uint256 valuesLen
    ) external {
        vm.assume(from != address(0));
        idsLen = bound(idsLen, 0, 5);
        valuesLen = bound(valuesLen, 0, 5);
        if (idsLen == valuesLen) valuesLen = (valuesLen + 1) % 6;
        uint256[] memory ids = new uint256[](idsLen);
        uint256[] memory values = new uint256[](valuesLen);
        for (uint256 i = 0; i < idsLen; i++) ids[i] = i;
        for (uint256 i = 0; i < valuesLen; i++) values[i] = 1;
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155BurnFacet.ERC1155InvalidArrayLength.selector, idsLen, valuesLen)
        );
        facet.burnBatch(from, ids, values);
    }

    function test_ShouldRevert_BurnBatch_WhenNotApprovedAndNotOwner() external {
        address(facet).setBalanceOf(1, users.alice, 100);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 50;
        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155BurnFacet.ERC1155MissingApprovalForAll.selector, users.bob, users.alice)
        );
        facet.burnBatch(users.alice, ids, values);
    }

    function test_ShouldRevert_BurnBatch_WhenInsufficientBalanceInLoop() external {
        address(facet).setBalanceOf(1, users.alice, 10);
        address(facet).setBalanceOf(2, users.alice, 0);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        values[0] = 10;
        values[1] = 1;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155BurnFacet.ERC1155InsufficientBalance.selector,
                users.alice,
                0,
                1,
                2
            )
        );
        facet.burnBatch(users.alice, ids, values);
    }

    function test_ShouldDecrementBalances_BurnBatch_WhenApprovedOperator() external {
        address(facet).setBalanceOf(1, users.alice, 40);
        address(facet).setBalanceOf(2, users.alice, 60);
        address(facet).setApprovedForAll(users.alice, users.bob, true);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        values[0] = 40;
        values[1] = 60;
        vm.stopPrank();
        vm.prank(users.bob);
        facet.burnBatch(users.alice, ids, values);
        assertEq(address(facet).balanceOf(1, users.alice), 0, "id1");
        assertEq(address(facet).balanceOf(2, users.alice), 0, "id2");
    }

    function testFuzz_ShouldDecrementBalances_BurnBatch_WhenPreconditionsHold(
        address from,
        uint256 id0,
        uint256 id1,
        uint256 v0,
        uint256 v1
    ) external {
        vm.assume(from != address(0));
        vm.assume(id0 != id1);
        vm.assume(v0 != type(uint256).max && v1 != type(uint256).max);
        address(facet).setBalanceOf(id0, from, v0);
        address(facet).setBalanceOf(id1, from, v1);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        values[0] = v0;
        values[1] = v1;
        vm.stopPrank();
        vm.prank(from);
        facet.burnBatch(from, ids, values);
        assertEq(address(facet).balanceOf(id0, from), 0, "balance id0");
        assertEq(address(facet).balanceOf(id1, from), 0, "balance id1");
    }
}
