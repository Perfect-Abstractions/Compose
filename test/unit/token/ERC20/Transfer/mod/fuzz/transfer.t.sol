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
contract Transfer_ERC20TransferMod_Fuzz_Unit_Test is ERC20TransferMod_Base_Test {
    using ERC20StorageUtils for address;

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

        address(harness).mint(users.alice, balance);

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

        address(harness).mint(users.alice, balance);

        uint256 beforeBalanceOfAlice = address(harness).balanceOf(users.alice);
        uint256 beforeBalanceOfTo = address(harness).balanceOf(to);

        vm.expectEmit(address(harness));
        emit Transfer(users.alice, to, value);
        bool result = harness.transfer(to, value);

        assertEq(result, true, "transfer failed");
        assertEq(address(harness).balanceOf(users.alice), beforeBalanceOfAlice - value, "balanceOf(users.alice)");
        assertEq(address(harness).balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
    }
}
