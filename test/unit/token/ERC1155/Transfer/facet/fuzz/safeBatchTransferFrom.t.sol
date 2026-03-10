// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155TransferFacet_Base_Test} from "test/unit/token/ERC1155/Transfer/ERC1155TransferFacetBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155TransferFacet} from "src/token/ERC1155/Transfer/ERC1155TransferFacet.sol";
import {ERC1155ReceiverMock} from "test/mocks/ERC1155ReceiverMock.sol";
import {RevertingReceiver} from "test/unit/token/ERC1155/Transfer/facet/fuzz/safeTransferFrom.t.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract SafeBatchTransferFrom_ERC1155TransferFacet_Fuzz_Test is ERC1155TransferFacet_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_SafeBatchTransferFrom_WhenIdsLengthNotEqualToValuesLength(
        address from,
        address to,
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
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidArrayLength.selector, idsLen, valuesLen)
        );
        facet.safeBatchTransferFrom(from, to, ids, values, "");
    }

    function test_ShouldRevert_SafeBatchTransferFrom_WhenFromIsZeroAddress() external {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 10;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidSender.selector, address(0)));
        facet.safeBatchTransferFrom(address(0), users.bob, ids, values, "");
    }

    function testFuzz_ShouldRevert_SafeBatchTransferFrom_WhenToIsZeroAddress(
        address from,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        address(facet).setBalanceOf(id, from, value);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = id;
        values[0] = value;
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidReceiver.selector, address(0)));
        facet.safeBatchTransferFrom(from, address(0), ids, values, "");
    }

    function testFuzz_ShouldRevert_SafeBatchTransferFrom_WhenInsufficientBalance(
        address from,
        address to,
        uint256 id,
        uint256 balance,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(to != from);
        vm.assume(to.code.length == 0);
        vm.assume(balance < type(uint256).max);
        value = bound(value, balance + 1, type(uint256).max);
        address(facet).setBalanceOf(id, from, balance);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = id;
        values[0] = value;
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC1155TransferFacet.ERC1155InsufficientBalance.selector,
                from,
                balance,
                value,
                id
            )
        );
        facet.safeBatchTransferFrom(from, to, ids, values, "");
    }

    function testFuzz_ShouldUpdateBalances_SafeBatchTransferFrom_WhenPreconditionsHold(
        address from,
        address to,
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
        facet.safeBatchTransferFrom(from, to, ids, values, "");
        assertEq(address(facet).balanceOf(id0, from), 0, "from id0");
        assertEq(address(facet).balanceOf(id1, from), 0, "from id1");
        assertEq(address(facet).balanceOf(id0, to), v0, "to id0");
        assertEq(address(facet).balanceOf(id1, to), v1, "to id1");
    }

    function test_ShouldUpdateBalances_SafeBatchTransferFrom_WhenToIsReceiverContractAccepting() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.None
        );
        address(facet).setBalanceOf(1, users.alice, 20);
        address(facet).setBalanceOf(2, users.alice, 30);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        values[0] = 20;
        values[1] = 30;
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, "");
        assertEq(address(facet).balanceOf(1, address(receiver)), 20, "to id1");
        assertEq(address(facet).balanceOf(2, address(receiver)), 30, "to id2");
    }

    function test_ShouldRevert_SafeBatchTransferFrom_WhenReceiverContractReturnsWrongValue() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            bytes4(0),
            bytes4(0),
            ERC1155ReceiverMock.RevertType.None
        );
        address(facet).setBalanceOf(1, users.alice, 10);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 10;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, "");
    }

    function test_ShouldRevert_SafeBatchTransferFrom_WhenReceiverRevertsWithNoData() external {
        RevertingReceiver receiver = new RevertingReceiver(false);
        address(facet).setBalanceOf(1, users.alice, 10);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 10;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, "");
    }

    function test_ShouldRevert_SafeBatchTransferFrom_WhenReceiverRevertsWithMessage() external {
        RevertingReceiver receiver = new RevertingReceiver(true);
        address(facet).setBalanceOf(1, users.alice, 10);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 10;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert("ERC1155Receiver: revert");
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, "");
    }

    function test_ShouldRevert_SafeBatchTransferFrom_WhenReceiverPanics() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.Panic
        );
        address(facet).setBalanceOf(1, users.alice, 10);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 10;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert();
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, "");
    }

    function test_ShouldRevert_SafeBatchTransferFrom_WhenReceiverRevertsWithCustomError() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.RevertWithCustomError
        );
        address(facet).setBalanceOf(1, users.alice, 10);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = 1;
        values[0] = 10;
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155ReceiverMock.CustomError.selector, RECEIVER_BATCH_MAGIC_VALUE)
        );
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, "");
    }

    function test_ShouldForwardData_SafeBatchTransferFrom_WhenToIsReceiverContract() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.None
        );
        address(facet).setBalanceOf(1, users.alice, 50);
        address(facet).setBalanceOf(2, users.alice, 100);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        values[0] = 50;
        values[1] = 100;
        bytes memory data = hex"c0ffee";
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, false);
        emit ERC1155ReceiverMock.BatchReceived(users.alice, users.alice, ids, values, data, 0);
        facet.safeBatchTransferFrom(users.alice, address(receiver), ids, values, data);
    }

    function test_ShouldSucceed_SafeBatchTransferFrom_WhenEmptyArrays() external {
        uint256[] memory ids;
        uint256[] memory values;
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeBatchTransferFrom(users.alice, users.bob, ids, values, "");
    }

    function test_ShouldUpdateBalances_SafeBatchTransferFrom_WhenSomeAmountsZero() external {
        address(facet).setBalanceOf(1, users.alice, 100);
        address(facet).setBalanceOf(2, users.alice, 200);
        address(facet).setBalanceOf(3, users.alice, 300);
        uint256[] memory ids = new uint256[](3);
        uint256[] memory values = new uint256[](3);
        ids[0] = 1;
        ids[1] = 2;
        ids[2] = 3;
        values[0] = 30;
        values[1] = 0;
        values[2] = 50;
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeBatchTransferFrom(users.alice, users.bob, ids, values, "");
        assertEq(address(facet).balanceOf(1, users.alice), 70);
        assertEq(address(facet).balanceOf(2, users.alice), 200);
        assertEq(address(facet).balanceOf(3, users.alice), 250);
        assertEq(address(facet).balanceOf(1, users.bob), 30);
        assertEq(address(facet).balanceOf(2, users.bob), 0);
        assertEq(address(facet).balanceOf(3, users.bob), 50);
    }

    function test_ShouldUpdateBalances_SafeBatchTransferFrom_WhenDuplicateTokenIds() external {
        address(facet).setBalanceOf(1, users.alice, 100);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = 1;
        ids[1] = 1;
        values[0] = 10;
        values[1] = 20;
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeBatchTransferFrom(users.alice, users.bob, ids, values, "");
        assertEq(address(facet).balanceOf(1, users.alice), 70);
        assertEq(address(facet).balanceOf(1, users.bob), 30);
    }
}
