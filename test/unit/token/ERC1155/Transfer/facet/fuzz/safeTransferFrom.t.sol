// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155TransferFacet_Base_Test} from "test/unit/token/ERC1155/Transfer/ERC1155TransferFacetBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import {ERC1155TransferFacet} from "src/token/ERC1155/Transfer/ERC1155TransferFacet.sol";
import {ERC1155ReceiverMock} from "test/mocks/ERC1155ReceiverMock.sol";
import {IERC1155Receiver} from "src/interfaces/IERC1155Receiver.sol";

/**
 * @dev Reverting receiver to cover catch branches (reason.length == 0 and reason.length > 0).
 */
contract RevertingReceiver is IERC1155Receiver {
    bool public revertWithMessage;

    constructor(bool _revertWithMessage) {
        revertWithMessage = _revertWithMessage;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (revertWithMessage) revert("ERC1155Receiver: revert");
        revert();
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        if (revertWithMessage) revert("ERC1155Receiver: revert");
        revert();
    }
}

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract SafeTransferFrom_ERC1155TransferFacet_Fuzz_Test is ERC1155TransferFacet_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenToIsZeroAddress(address from, uint256 id, uint256 value)
        external
    {
        vm.assume(from != address(0));
        address(facet).setBalanceOf(id, from, value);
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidReceiver.selector, address(0)));
        facet.safeTransferFrom(from, address(0), id, value, "");
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenFromIsZeroAddress(address to, uint256 id, uint256 value)
        external
    {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidSender.selector, address(0)));
        facet.safeTransferFrom(address(0), to, id, value, "");
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenNotApprovedAndNotOwner(
        address from,
        address to,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(to != from);
        vm.assume(from != users.bob);
        vm.assume(to.code.length == 0);
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, from, value);
        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155TransferFacet.ERC1155MissingApprovalForAll.selector, users.bob, from)
        );
        facet.safeTransferFrom(from, to, id, value, "");
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenInsufficientBalance(
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
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InsufficientBalance.selector, from, balance, value, id)
        );
        facet.safeTransferFrom(from, to, id, value, "");
    }

    function testFuzz_ShouldUpdateBalances_SafeTransferFrom_WhenPreconditionsHold(
        address from,
        address to,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(to.code.length == 0);
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, from, value);
        vm.stopPrank();
        vm.prank(from);
        facet.safeTransferFrom(from, to, id, value, "");
        assertEq(address(facet).balanceOf(id, from), 0, "from balance");
        assertEq(address(facet).balanceOf(id, to), value, "to balance");
    }

    function testFuzz_ShouldUpdateBalances_SafeTransferFrom_WhenApprovedOperator(
        address from,
        address to,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(to != users.alice);
        vm.assume(to.code.length == 0);
        vm.assume(value != type(uint256).max);
        address(facet).setBalanceOf(id, from, value);
        address(facet).setApprovedForAll(from, users.alice, true);
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeTransferFrom(from, to, id, value, "");
        assertEq(address(facet).balanceOf(id, from), 0, "from balance");
        assertEq(address(facet).balanceOf(id, to), value, "to balance");
    }

    function test_ShouldUpdateBalances_SafeTransferFrom_WhenValueIsZero() external {
        address(facet).setBalanceOf(1, users.alice, 100);
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeTransferFrom(users.alice, users.bob, 1, 0, "");
        assertEq(address(facet).balanceOf(1, users.alice), 100, "from unchanged");
        assertEq(address(facet).balanceOf(1, users.bob), 0, "to unchanged");
    }

    function test_ShouldUpdateBalances_SafeTransferFrom_WhenToIsReceiverContractAccepting() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );
        address(facet).setBalanceOf(1, users.alice, 50);
        vm.stopPrank();
        vm.prank(users.alice);
        facet.safeTransferFrom(users.alice, address(receiver), 1, 50, "");
        assertEq(address(facet).balanceOf(1, users.alice), 0, "from balance");
        assertEq(address(facet).balanceOf(1, address(receiver)), 50, "to balance");
    }

    function test_ShouldRevert_SafeTransferFrom_WhenReceiverContractReturnsWrongValue() external {
        ERC1155ReceiverMock receiver =
            new ERC1155ReceiverMock(bytes4(0), bytes4(0), ERC1155ReceiverMock.RevertType.None);
        address(facet).setBalanceOf(1, users.alice, 10);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(users.alice, address(receiver), 1, 10, "");
    }

    function test_ShouldRevert_SafeTransferFrom_WhenReceiverRevertsWithNoData() external {
        RevertingReceiver receiver = new RevertingReceiver(false);
        address(facet).setBalanceOf(1, users.alice, 10);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155TransferFacet.ERC1155InvalidReceiver.selector, address(receiver)));
        facet.safeTransferFrom(users.alice, address(receiver), 1, 10, "");
    }

    function test_ShouldRevert_SafeTransferFrom_WhenReceiverRevertsWithMessage() external {
        RevertingReceiver receiver = new RevertingReceiver(true);
        address(facet).setBalanceOf(1, users.alice, 10);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert("ERC1155Receiver: revert");
        facet.safeTransferFrom(users.alice, address(receiver), 1, 10, "");
    }

    function test_ShouldRevert_SafeTransferFrom_WhenReceiverPanics() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.Panic
        );
        address(facet).setBalanceOf(1, users.alice, 10);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert();
        facet.safeTransferFrom(users.alice, address(receiver), 1, 10, "");
    }

    function test_ShouldRevert_SafeTransferFrom_WhenReceiverRevertsWithCustomError() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE,
            RECEIVER_BATCH_MAGIC_VALUE,
            ERC1155ReceiverMock.RevertType.RevertWithCustomError
        );
        address(facet).setBalanceOf(1, users.alice, 10);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC1155ReceiverMock.CustomError.selector, RECEIVER_SINGLE_MAGIC_VALUE));
        facet.safeTransferFrom(users.alice, address(receiver), 1, 10, "");
    }

    function test_ShouldForwardData_SafeTransferFrom_WhenToIsReceiverContract() external {
        ERC1155ReceiverMock receiver = new ERC1155ReceiverMock(
            RECEIVER_SINGLE_MAGIC_VALUE, RECEIVER_BATCH_MAGIC_VALUE, ERC1155ReceiverMock.RevertType.None
        );
        address(facet).setBalanceOf(1, users.alice, 50);
        bytes memory data = hex"deadbeef";
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, false);
        emit ERC1155ReceiverMock.Received(users.alice, users.alice, 1, 50, data, 0);
        facet.safeTransferFrom(users.alice, address(receiver), 1, 50, data);
    }
}
