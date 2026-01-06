// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20TransferFacet} from "src/token/ERC20/ERC20/ERC20TransferFacet.sol";

import {ERC20TransferFacet_Base_Test} from "../ERC20TransferFacetBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

/// @dev BTT spec: test/trees/ERC20.tree
contract Transfer_ERC20TransferFacet_Fuzz_Unit_Test is ERC20TransferFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_ReceiverIsZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20TransferFacet.ERC20InvalidReceiver.selector, ADDRESS_ZERO));
        facet.transfer(ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_CallerInsufficientBalance(address to, uint256 balance, uint256 value)
        external
        whenReceiverNotZeroAddress
    {
        vm.assume(to != ADDRESS_ZERO);
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);

        address(facet).mint(users.alice, balance);

        vm.expectRevert(
            abi.encodeWithSelector(ERC20TransferFacet.ERC20InsufficientBalance.selector, users.alice, balance, value)
        );
        facet.transfer(to, value);
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

        address(facet).mint(users.alice, balance);

        uint256 beforeBalanceOfAlice = facet.balanceOf(users.alice);
        uint256 beforeBalanceOfTo = facet.balanceOf(to);

        vm.expectEmit(address(facet));
        emit ERC20TransferFacet.Transfer(users.alice, to, value);
        bool result = facet.transfer(to, value);

        assertEq(result, true, "transfer failed");
        assertEq(facet.balanceOf(users.alice), beforeBalanceOfAlice - value, "balanceOf(users.alice)");
        assertEq(facet.balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
    }
}
