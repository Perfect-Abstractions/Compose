// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "../../../../Base.t.sol";

import {ERC20Harness} from "../harnesses/ERC20Harness.sol";
import "../../../../../src/token/ERC20/ERC20/ERC20Mod.sol" as ERC20Mod;

contract Mint_ERC20Mod_Fuzz_Unit_Test is Base_Test {
    ERC20Harness internal harness;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    function setUp() public override {
        Base_Test.setUp();

        harness = new ERC20Harness();
    }

    function testFuzz_ShouldRevert_Account_ZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20Mod.ERC20InvalidReceiver.selector, address(0)));
        harness.mint(ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_TotalSupply_Overflows(address account, uint256 value)
        external
        whenAccountNotZeroAddress
    {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(value > 0);

        harness.mint(users.alice, MAX_UINT256);

        vm.expectRevert(stdError.arithmeticError);
        harness.mint(account, value);
    }

    function testFuzz_Mint(address account, uint256 value)
        external
        whenAccountNotZeroAddress
        givenWhenTotalSupplyNotOverflow
    {
        vm.assume(account != ADDRESS_ZERO);

        uint256 beforeTotalSupply = harness.totalSupply();
        uint256 beforeBalanceOfAccount = harness.balanceOf(account);

        vm.expectEmit(address(harness));
        emit Transfer(ADDRESS_ZERO, account, value);
        harness.mint(account, value);

        assertEq(harness.totalSupply(), beforeTotalSupply + value, "totalSupply");
        assertEq(harness.balanceOf(account), beforeBalanceOfAccount + value, "balanceOf(account)");
    }
}

