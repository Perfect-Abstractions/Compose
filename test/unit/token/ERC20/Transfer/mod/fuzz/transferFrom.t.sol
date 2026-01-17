// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {ERC20TransferMod_Base_Test} from "../ERC20TransferModBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

import "src/token/ERC20/Transfer/ERC20TransferMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract TransferFrom_ERC20TransferMod_Fuzz_Unit_Test is ERC20TransferMod_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_SenderIsZeroAddress(address to, uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSender.selector, ADDRESS_ZERO));
        harness.transferFrom(ADDRESS_ZERO, to, value);
    }

    function testFuzz_ShouldRevert_ReceiverIsZeroAddress(address from, uint256 value)
        external
        whenSenderNotZeroAddress
    {
        vm.assume(from != ADDRESS_ZERO);

        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, ADDRESS_ZERO));
        harness.transferFrom(from, ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_SpenderAllowanceLtAmount(address from, address to, uint256 value, uint256 allowance)
        external
        whenSenderNotZeroAddress
        whenReceiverNotZeroAddress
    {
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(to != ADDRESS_ZERO);
        allowance = bound(allowance, 0, MAX_UINT256 - 1);
        value = bound(value, allowance + 1, MAX_UINT256);

        address(harness).setAllowance(from, users.sender, allowance);
        setMsgSender(users.sender);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientAllowance.selector, users.sender, allowance, value));
        harness.transferFrom(from, to, value);
    }

    function testFuzz_ShouldRevert_SenderBalanceLtAmount(
        address from,
        address to,
        uint256 value,
        uint256 allowance,
        uint256 balance
    ) external whenSenderNotZeroAddress whenReceiverNotZeroAddress givenWhenSpenderAllowanceGETransferAmount {
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(to != ADDRESS_ZERO);

        value = bound(value, 1, MAX_UINT256);
        allowance = bound(allowance, value, MAX_UINT256); // allowance >= value
        balance = bound(balance, 0, value - 1); // balance < value

        address(harness).mint(from, balance);
        address(harness).setAllowance(from, users.sender, allowance);
        setMsgSender(users.sender);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, from, balance, value));
        harness.transferFrom(from, to, value);
    }

    function testFuzz_TransferFrom_InfiniteApproval(address from, address to, uint256 value, uint256 balance)
        external
        whenSenderNotZeroAddress
        whenReceiverNotZeroAddress
        givenWhenSpenderAllowanceGETransferAmount
        givenWhenSenderBalanceGETransferAmount
    {
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != from);
        vm.assume(users.sender != from);

        value = bound(value, 1, MAX_UINT256);
        balance = bound(balance, value, MAX_UINT256);

        address(harness).mint(from, balance);
        address(harness).setAllowance(from, users.sender, MAX_UINT256);
        setMsgSender(users.sender);

        uint256 beforeBalanceOfFrom = address(harness).balanceOf(from);
        uint256 beforeBalanceOfTo = address(harness).balanceOf(to);

        vm.expectEmit(address(harness));
        emit Transfer(from, to, value);
        bool result = harness.transferFrom(from, to, value);

        assertEq(result, true, "transfer failed");
        assertEq(address(harness).balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
        assertEq(address(harness).balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
    }

    function testFuzz_TransferFrom(address from, address to, uint256 value, uint256 allowance, uint256 balance)
        external
        whenSenderNotZeroAddress
        whenReceiverNotZeroAddress
        givenWhenSpenderAllowanceGETransferAmount
        givenWhenSenderBalanceGETransferAmount
    {
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != from);
        vm.assume(users.sender != from);

        value = bound(value, 1, MAX_UINT256 - 1);
        allowance = bound(allowance, value, MAX_UINT256 - 1);
        balance = bound(balance, value, MAX_UINT256);

        address(harness).mint(from, balance);
        address(harness).setAllowance(from, users.sender, allowance);
        setMsgSender(users.sender);

        uint256 beforeBalanceOfFrom = address(harness).balanceOf(from);
        uint256 beforeBalanceOfTo = address(harness).balanceOf(to);

        vm.expectEmit(address(harness));
        emit Transfer(from, to, value);
        bool result = harness.transferFrom(from, to, value);

        assertEq(result, true, "transfer failed");
        assertEq(address(harness).balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
        assertEq(address(harness).balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
        assertEq(address(harness).allowance(from, users.sender), allowance - value, "allowance(from, users.sender)");
    }
}
