// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20MintModHarness} from "test/harnesses/token/ERC20/ERC20MintModHarness.sol";

import "src/token/ERC20/Mint/ERC20MintMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Mint_ERC20MintMod_Fuzz_Unit_Test is Base_Test {
    using ERC20StorageUtils for address;

    ERC20MintModHarness internal harness;

    function setUp() public override {
        Base_Test.setUp();
        harness = new ERC20MintModHarness();
        vm.label(address(harness), "ERC20MintModHarness");
    }

    function testFuzz_ShouldRevert_Account_ZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidReceiver.selector, address(0)));
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

        uint256 beforeTotalSupply = address(harness).totalSupply();
        uint256 beforeBalanceOfAccount = address(harness).balanceOf(account);

        vm.expectEmit(address(harness));
        emit Transfer(ADDRESS_ZERO, account, value);
        harness.mint(account, value);

        assertEq(address(harness).totalSupply(), beforeTotalSupply + value, "totalSupply");
        assertEq(address(harness).balanceOf(account), beforeBalanceOfAccount + value, "balanceOf(account)");
    }
}
