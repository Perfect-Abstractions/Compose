// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155TransferMod_Base_Test} from "test/unit/token/ERC1155/Transfer/ERC1155TransferModBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import "src/token/ERC1155/Transfer/ERC1155TransferMod.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract SafeBatchTransferFrom_ERC1155TransferMod_Fuzz_Test is ERC1155TransferMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_SafeBatchTransferFrom_WhenIdsLengthNotEqualToValuesLength(
        address from,
        address to,
        address operator,
        uint256 idsLen,
        uint256 valuesLen
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        idsLen = bound(idsLen, 0, 5);
        valuesLen = bound(valuesLen, 0, 5);
        if (idsLen == valuesLen) valuesLen = (valuesLen + 1) % 6;
        uint256[] memory ids = new uint256[](idsLen);
        uint256[] memory values = new uint256[](valuesLen);
        for (uint256 i = 0; i < idsLen; i++) ids[i] = i;
        for (uint256 i = 0; i < valuesLen; i++) values[i] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155InvalidArrayLength.selector, idsLen, valuesLen)
        );
        harness.safeBatchTransferFrom(from, to, ids, values, operator);
    }

    function testFuzz_ShouldRevert_SafeBatchTransferFrom_WhenToIsZeroAddress(
        address from,
        address operator,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        address(harness).setBalanceOf(id, from, value);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = id;
        values[0] = value;
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(0)));
        harness.safeBatchTransferFrom(from, address(0), ids, values, operator);
    }

    function testFuzz_ShouldUpdateBalances_SafeBatchTransferFrom_WhenPreconditionsHold(
        address from,
        address to,
        address operator,
        uint256 id0,
        uint256 id1,
        uint256 v0,
        uint256 v1
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(to.code.length == 0);
        vm.assume(id0 != id1);
        vm.assume(v0 != type(uint256).max && v1 != type(uint256).max);
        address(harness).setBalanceOf(id0, from, v0);
        address(harness).setBalanceOf(id1, from, v1);
        if (operator != from) {
            address(harness).setApprovedForAll(from, operator, true);
        }
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        values[0] = v0;
        values[1] = v1;
        harness.safeBatchTransferFrom(from, to, ids, values, operator);
        assertEq(address(harness).balanceOf(id0, from), 0, "from id0");
        assertEq(address(harness).balanceOf(id1, from), 0, "from id1");
        assertEq(address(harness).balanceOf(id0, to), v0, "to id0");
        assertEq(address(harness).balanceOf(id1, to), v1, "to id1");
    }
}
