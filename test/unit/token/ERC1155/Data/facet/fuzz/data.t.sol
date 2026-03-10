// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155DataFacet_Base_Test} from "test/unit/token/ERC1155/Data/ERC1155DataFacetBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155DataFacet} from "src/token/ERC1155/Data/ERC1155DataFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract Data_ERC1155DataFacet_Fuzz_Test is ERC1155DataFacet_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldReturnBalance_BalanceOf_WhenAccountAndIdQueried(
        address account,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, account, value);

        assertEq(facet.balanceOf(account, id), value, "balanceOf");
    }

    function testFuzz_ShouldReturnZero_BalanceOf_WhenAccountIsZeroAddress(uint256 id) external view {
        assertEq(facet.balanceOf(address(0), id), 0, "balanceOf zero address");
    }

    function testFuzz_ShouldRevert_BalanceOfBatch_WhenAccountsLengthNotEqualToIdsLength(
        uint256 accountsLen,
        uint256 idsLen
    ) external {
        accountsLen = bound(accountsLen, 0, 10);
        idsLen = bound(idsLen, 0, 10);
        vm.assume(accountsLen != idsLen);

        address[] memory accounts = new address[](accountsLen);
        uint256[] memory ids = new uint256[](idsLen);
        for (uint256 i = 0; i < accountsLen; i++) accounts[i] = makeAddr(string.concat("a", vm.toString(i)));
        for (uint256 i = 0; i < idsLen; i++) ids[i] = i;

        vm.expectRevert(
            abi.encodeWithSelector(ERC1155DataFacet.ERC1155InvalidArrayLength.selector, idsLen, accountsLen)
        );
        facet.balanceOfBatch(accounts, ids);
    }

    function testFuzz_ShouldReturnBalancesInOrder_BalanceOfBatch(
        address a0,
        address a1,
        uint256 id0,
        uint256 id1,
        uint256 v0,
        uint256 v1
    ) external {
        vm.assume(v0 != type(uint256).max && v1 != type(uint256).max);
        address(facet).setBalanceOf(id0, a0, v0);
        address(facet).setBalanceOf(id1, a1, v1);

        address[] memory accounts = new address[](2);
        accounts[0] = a0;
        accounts[1] = a1;
        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;

        uint256[] memory balances = facet.balanceOfBatch(accounts, ids);
        assertEq(balances.length, 2, "length");
        assertEq(balances[0], v0, "balance 0");
        assertEq(balances[1], v1, "balance 1");
    }

    function test_ShouldReturnEmptyArray_BalanceOfBatch_WhenArraysEmpty() external view {
        address[] memory accounts;
        uint256[] memory ids;
        uint256[] memory balances = facet.balanceOfBatch(accounts, ids);
        assertEq(balances.length, 0, "empty");
    }

    function testFuzz_ShouldReturnFalse_IsApprovedForAll_WhenNotApproved(
        address account,
        address operator
    ) external view {
        assertEq(facet.isApprovedForAll(account, operator), false, "isApprovedForAll");
    }

    function testFuzz_ShouldReturnTrue_IsApprovedForAll_WhenApproved(
        address account,
        address operator
    ) external {
        address(facet).setApprovedForAll(account, operator, true);
        assertEq(facet.isApprovedForAll(account, operator), true, "isApprovedForAll");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(
            ERC1155DataFacet.balanceOf.selector,
            ERC1155DataFacet.balanceOfBatch.selector,
            ERC1155DataFacet.isApprovedForAll.selector
        );
        assertEq(selectors, expected, "exportSelectors");
    }
}
