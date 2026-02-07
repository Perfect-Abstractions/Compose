// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20BurnModHarness} from "test/harnesses/token/ERC20/ERC20BurnModHarness.sol";

import "src/token/ERC20/Burn/ERC20BurnMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Burn_ERC20BurnMod_Fuzz_Unit_Test is Base_Test {
    using ERC20StorageUtils for address;

    ERC20BurnModHarness internal harness;

    function setUp() public override {
        Base_Test.setUp();
        harness = new ERC20BurnModHarness();
        vm.label(address(harness), "ERC20BurnModHarness");
    }

    function testFuzz_ShouldRevert_Account_ZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSender.selector, address(0)));
        harness.burn(ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_AccountBalanceLtBurnAmount(address account, uint256 balance, uint256 value)
        external
        whenAccountNotZeroAddress
    {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);

        address(harness).mint(account, balance);

        vm.expectRevert(abi.encodeWithSelector(ERC20InsufficientBalance.selector, account, balance, value));
        harness.burn(account, value);
    }

    function testFuzz_Burn(address account, uint256 balance, uint256 value)
        external
        whenAccountNotZeroAddress
        givenWhenAccountBalanceGEBurnAmount
    {
        vm.assume(account != ADDRESS_ZERO);
        balance = bound(balance, 1, MAX_UINT256);
        value = bound(value, 1, balance);

        address(harness).mint(account, balance);

        uint256 beforeTotalSupply = address(harness).totalSupply();
        uint256 beforeBalanceOfAccount = address(harness).balanceOf(account);

        vm.expectEmit(address(harness));
        emit Transfer(account, ADDRESS_ZERO, value);
        harness.burn(account, value);

        assertEq(address(harness).totalSupply(), beforeTotalSupply - value, "totalSupply");
        assertEq(address(harness).balanceOf(account), beforeBalanceOfAccount - value, "balanceOf(account)");
    }
}
