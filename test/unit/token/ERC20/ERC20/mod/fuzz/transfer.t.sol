// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20Harness} from "test/harnesses/token/ERC20/ERC20/ERC20Harness.sol";

import "src/token/ERC20/ERC20/ERC20Mod.sol";

/// @dev BTT spec: test/trees/ERC20.tree
contract Transfer_ERC20Mod_Fuzz_Unit_Test is Base_Test {
    ERC20Harness internal harness;

    function setUp() public override {
        Base_Test.setUp();
        harness = new ERC20Harness();
    }

    function testFuzz_ShouldRevert_ReceiverIsZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, ADDRESS_ZERO));
        harness.transfer(ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_CallerInsufficientBalance(address to, uint256 balance, uint256 value)
        external
        whenReceiverNotZeroAddress
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);

        harness.mint(users.alice, balance);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, users.alice, balance, value));
        harness.transfer(to, value);
    }

    function testFuzz_Transfer(address to, uint256 balance, uint256 value)
        external
        whenReceiverNotZeroAddress
        givenWhenSenderBalanceGETransferAmount
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(to != users.alice);
        balance = bound(balance, 1, MAX_UINT256);
        value = bound(value, 1, balance);

        harness.mint(users.alice, balance);

        uint256 beforeBalanceOfAlice = harness.balanceOf(users.alice);
        uint256 beforeBalanceOfTo = harness.balanceOf(to);

        vm.expectEmit(address(harness));
        emit Transfer(users.alice, to, value);
        bool result = harness.transfer(to, value);

        assertEq(result, true, "transfer failed");
        assertEq(harness.balanceOf(users.alice), beforeBalanceOfAlice - value, "balanceOf(users.alice)");
        assertEq(harness.balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
    }
}
