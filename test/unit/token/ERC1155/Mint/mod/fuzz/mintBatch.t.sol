// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155MintMod_Base_Test} from "test/unit/token/ERC1155/Mint/ERC1155MintModBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155ReceiverMock} from "test/mocks/ERC1155ReceiverMock.sol";
import "src/token/ERC1155/Mint/ERC1155MintMod.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract MintBatch_ERC1155MintMod_Fuzz_Test is ERC1155MintMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_MintBatch_WhenToIsZeroAddress(uint256 idsLen, uint256 v) external {
        vm.assume(idsLen <= 10);
        uint256[] memory ids = new uint256[](idsLen);
        uint256[] memory values = new uint256[](idsLen);
        for (uint256 i = 0; i < idsLen; i++) {
            ids[i] = i;
            values[i] = v;
        }
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(0)));
        harness.mintBatch(address(0), ids, values, "");
    }

    function testFuzz_ShouldRevert_MintBatch_WhenIdsLengthNotEqualToValuesLength(
        address to,
        uint256 idsLen,
        uint256 valuesLen
    ) external {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        idsLen = bound(idsLen, 0, 5);
        valuesLen = bound(valuesLen, 0, 5);
        if (idsLen == valuesLen) valuesLen = (valuesLen + 1) % 6;

        uint256[] memory ids = new uint256[](idsLen);
        uint256[] memory values = new uint256[](valuesLen);
        for (uint256 i = 0; i < idsLen; i++) {
            ids[i] = i;
        }
        for (uint256 i = 0; i < valuesLen; i++) {
            values[i] = 1;
        }

        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidArrayLength.selector, idsLen, valuesLen));
        harness.mintBatch(to, ids, values, "");
    }

    function testFuzz_ShouldIncrementBalancesAndEmit_MintBatch_WhenPreconditionsHold(
        address to,
        uint256 id0,
        uint256 id1,
        uint256 v0,
        uint256 v1
    ) external {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.assume(id0 != id1);
        vm.assume(v0 != type(uint256).max && v1 != type(uint256).max);

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256[] memory values = new uint256[](2);
        values[0] = v0;
        values[1] = v1;

        harness.mintBatch(to, ids, values, "");

        assertEq(address(harness).balanceOf(id0, to), v0, "balance id0");
        assertEq(address(harness).balanceOf(id1, to), v1, "balance id1");
    }

    function test_ShouldSucceed_MintBatch_WhenEmptyArrays(address to) external {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        uint256[] memory ids;
        uint256[] memory values;
        harness.mintBatch(to, ids, values, "");
    }

    function testFuzz_ShouldIncrementBalances_MintBatch_WhenToIsReceiverContract(
        uint256 id0,
        uint256 id1,
        uint256 v0,
        uint256 v1
    ) external {
        vm.assume(id0 != id1);
        vm.assume(v0 != type(uint256).max && v1 != type(uint256).max);
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );

        uint256[] memory ids = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        uint256[] memory values = new uint256[](2);
        values[0] = v0;
        values[1] = v1;

        harness.mintBatch(address(receiver), ids, values, "");

        assertEq(address(harness).balanceOf(id0, address(receiver)), v0, "balance id0");
        assertEq(address(harness).balanceOf(id1, address(receiver)), v1, "balance id1");
    }

    function test_ShouldRevert_MintBatch_WhenReceiverContractReturnsWrongValue() external {
        /* Receiver returns single magic for batch (wrong return for onERC1155BatchReceived) */
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_SINGLE_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 100;
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(receiver)));
        harness.mintBatch(address(receiver), ids, values, "");
    }
}
