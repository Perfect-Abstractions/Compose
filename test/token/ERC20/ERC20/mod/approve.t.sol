// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "../../../../Base.t.sol";

import {ERC20Harness} from "../harnesses/ERC20Harness.sol";
import "../../../../../src/token/ERC20/ERC20/ERC20Mod.sol" as ERC20Mod;

contract Approve_ERC20Mod_Fuzz_Unit_Test is Base_Test {
    ERC20Harness internal harness;

    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public override {
        Base_Test.setUp();

        harness = new ERC20Harness();
    }

    function testFuzz_ShouldRevert_SpenderIsZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20Mod.ERC20InvalidSpender.selector, ADDRESS_ZERO));
        harness.approve(ADDRESS_ZERO, value);
    }

    function testFuzz_Approve(address spender, uint256 value) external whenSpenderNotZeroAddress {
        vm.assume(spender != ADDRESS_ZERO);

        vm.expectEmit(address(harness));
        emit Approval(users.alice, spender, value);
        harness.approve(spender, value);

        assertEq(harness.allowance(users.alice, spender), value);
    }
}

