// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20TransferFacet_Base_Test} from "../ERC20TransferFacetBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

import {ERC20TransferFacet} from "src/token/ERC20/Transfer/ERC20TransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract TransferFrom_ERC20TransferFacet_Fuzz_Unit_Test is ERC20TransferFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_SenderIsZeroAddress(address to, uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20TransferFacet.ERC20InvalidSender.selector, ADDRESS_ZERO));
        facet.transferFrom(ADDRESS_ZERO, to, value);
    }

    function testFuzz_ShouldRevert_ReceiverIsZeroAddress(address from, uint256 value)
        external
        whenSenderNotZeroAddress
    {
        vm.assume(from != ADDRESS_ZERO);

        vm.expectRevert(abi.encodeWithSelector(ERC20TransferFacet.ERC20InvalidReceiver.selector, ADDRESS_ZERO));
        facet.transferFrom(from, ADDRESS_ZERO, value);
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

        address(facet).setAllowance(from, users.sender, allowance);
        setMsgSender(users.sender);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20TransferFacet.ERC20InsufficientAllowance.selector, users.sender, allowance, value
            )
        );
        facet.transferFrom(from, to, value);
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

        address(facet).mint(from, balance);
        address(facet).setAllowance(from, users.sender, allowance);
        setMsgSender(users.sender);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20TransferFacet.ERC20InsufficientBalance.selector, from, balance, value)
        );
        facet.transferFrom(from, to, value);
    }

    function testFuzz_ShouldReturnTrue_AmountIsZero(
        address from,
        address to,
        uint256 allowance,
        uint256 fromBalance,
        uint256 toBalance
    )
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

        allowance = bound(allowance, 0, MAX_UINT256);
        fromBalance = bound(fromBalance, 0, MAX_UINT256 / 2);
        toBalance = bound(toBalance, 0, MAX_UINT256 / 2);

        address(facet).mint(from, fromBalance);
        address(facet).mint(to, toBalance);

        address(facet).setAllowance(from, users.sender, allowance);

        uint256 beforeAllowance = address(facet).allowance(from, users.sender);

        vm.expectEmit(address(facet));
        emit ERC20TransferFacet.Transfer(from, to, 0);
        bool result = facet.transferFrom(from, to, 0);

        assertEq(result, true, "transferFrom failed");
        assertEq(address(facet).balanceOf(from), fromBalance, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), toBalance, "balanceOf(to)");
        assertEq(address(facet).allowance(from, users.sender), beforeAllowance, "allowance should be unchanged");
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

        address(facet).mint(from, balance);
        address(facet).setAllowance(from, users.sender, MAX_UINT256);
        setMsgSender(users.sender);

        uint256 beforeBalanceOfFrom = address(facet).balanceOf(from);
        uint256 beforeBalanceOfTo = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC20TransferFacet.Transfer(from, to, value);
        bool result = facet.transferFrom(from, to, value);

        assertEq(result, true, "transfer failed");
        assertEq(address(facet).balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
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

        address(facet).mint(from, balance);
        address(facet).setAllowance(from, users.sender, allowance);
        setMsgSender(users.sender);

        uint256 beforeBalanceOfFrom = address(facet).balanceOf(from);
        uint256 beforeBalanceOfTo = address(facet).balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC20TransferFacet.Transfer(from, to, value);
        bool result = facet.transferFrom(from, to, value);

        assertEq(result, true, "transfer failed");
        assertEq(address(facet).balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
        assertEq(address(facet).balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
        assertEq(address(facet).allowance(from, users.sender), allowance - value, "allowance(from, users.sender)");
    }
}
