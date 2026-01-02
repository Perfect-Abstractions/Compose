// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20Harness} from "test/harnesses/token/ERC20/ERC20/ERC20Harness.sol";

import "src/token/ERC20/ERC20/ERC20Mod.sol" as ERC20Mod;

contract Burn_ERC20Mod_Fuzz_Unit_Test is Base_Test {
    ERC20Harness internal harness;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    function setUp() public override {
        Base_Test.setUp();

        harness = new ERC20Harness();
    }

    function testFuzz_ShouldRevert_Account_ZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20Mod.ERC20InvalidSender.selector, address(0)));
        harness.burn(ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_AccountBalanceLtBurnAmount(address account, uint256 balance, uint256 value)
        external
        whenAccountNotZeroAddress
    {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);

        harness.mint(account, balance);

        vm.expectRevert(abi.encodeWithSelector(ERC20Mod.ERC20InsufficientBalance.selector, account, balance, value));
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

        harness.mint(account, balance);

        uint256 beforeTotalSupply = harness.totalSupply();
        uint256 beforeBalanceOfAccount = harness.balanceOf(account);

        vm.expectEmit(address(harness));
        emit Transfer(account, ADDRESS_ZERO, value);
        harness.burn(account, value);

        assertEq(harness.totalSupply(), beforeTotalSupply - value, "totalSupply");
        assertEq(harness.balanceOf(account), beforeBalanceOfAccount - value, "balanceOf(account)");
    }
}

