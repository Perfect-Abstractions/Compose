// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20Harness} from "test/harnesses/token/ERC20/ERC20/ERC20Harness.sol";

import "src/token/ERC20/ERC20/ERC20Mod.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract TransferFrom_ERC20Mod_Fuzz_Unit_Test is Base_Test {
    ERC20Harness internal harness;

    function setUp() public override {
        Base_Test.setUp();
        harness = new ERC20Harness();
    }

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

        setMsgSender(from);
        harness.approve(users.sender, allowance);
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

        harness.mint(from, balance);

        setMsgSender(from);
        harness.approve(users.sender, allowance);
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

        harness.mint(from, balance);

        setMsgSender(from);
        harness.approve(users.sender, MAX_UINT256);
        setMsgSender(users.sender);

        uint256 beforeBalanceOfFrom = harness.balanceOf(from);
        uint256 beforeBalanceOfTo = harness.balanceOf(to);

        vm.expectEmit(address(harness));
        emit Transfer(from, to, value);
        bool result = harness.transferFrom(from, to, value);

        assertEq(result, true, "transfer failed");
        assertEq(harness.balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
        assertEq(harness.balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
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

        harness.mint(from, balance);

        setMsgSender(from);
        harness.approve(users.sender, allowance);
        setMsgSender(users.sender);

        uint256 beforeBalanceOfFrom = harness.balanceOf(from);
        uint256 beforeBalanceOfTo = harness.balanceOf(to);

        vm.expectEmit(address(harness));
        emit Transfer(from, to, value);
        bool result = harness.transferFrom(from, to, value);

        assertEq(result, true, "transfer failed");
        assertEq(harness.balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
        assertEq(harness.balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
        assertEq(harness.allowance(from, users.sender), allowance - value, "allowance(from, users.sender)");
    }
}
