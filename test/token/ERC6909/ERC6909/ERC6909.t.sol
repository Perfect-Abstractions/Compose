// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {ERC6909Harness} from "./harnesses/ERC6909Harness.sol";
import "../../../../src/token/ERC6909/ERC6909/ERC6909Mod.sol" as ERC6909Mod;
import {Transfer, OperatorSet, Approval} from "../../../../src/token/ERC6909/ERC6909/ERC6909Mod.sol";

contract LibERC6909Test is Test {
    ERC6909Harness internal harness;

    address internal alice;

    uint256 internal constant TOKEN_ID = 72;
    uint256 internal constant AMOUNT = 1e24;

    function setUp() public {
        alice = makeAddr("alice");

        harness = new ERC6909Harness();
    }

    /**
     * ============================================
     * Mint Tests
     * ============================================
     */

    function test_ShouldRevert_Mint_ToIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidReceiver.selector, address(0)));
        harness.mint(address(0), TOKEN_ID, AMOUNT);
    }

    function test_Mint() external {
        vm.expectEmit();
        emit Transfer(address(this), address(0), alice, TOKEN_ID, AMOUNT);

        harness.mint(alice, TOKEN_ID, AMOUNT);

        assertEq(harness.balanceOf(alice, TOKEN_ID), AMOUNT);
    }

    function test_ShouldRevert_Mint_BalanceOf_Overflows() external {
        harness.mint(alice, TOKEN_ID, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        harness.mint(alice, TOKEN_ID, 1);
    }

    function testFuzz_Mint(address caller, address to, uint256 id, uint256 amount) external {
        vm.assume(to != address(0));

        vm.expectEmit();
        emit Transfer(caller, address(0), to, id, amount);

        vm.prank(caller);
        harness.mint(to, id, amount);

        assertEq(harness.balanceOf(to, id), amount);
    }

    /**
     * ============================================
     * Burn Tests
     * ============================================
     */

    function test_ShouldRevert_Burn_InsufficientBalance() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InsufficientBalance.selector, alice, 0, 1, TOKEN_ID));
        harness.burn(alice, TOKEN_ID, 1);
    }

    function test_ShouldRevert_Burn_FromIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidSender.selector, address(0)));
        harness.burn(address(0), TOKEN_ID, 1);
    }

    function test_Burn() external {
        harness.mint(alice, TOKEN_ID, AMOUNT);

        vm.expectEmit();
        emit Transfer(address(this), alice, address(0), TOKEN_ID, AMOUNT);

        harness.burn(alice, TOKEN_ID, AMOUNT);

        assertEq(harness.balanceOf(alice, TOKEN_ID), 0);
    }

    /**
     * @dev First mints tokens and then burns a fraction of them.
     */
    function testFuzz_Burn(address caller, address from, uint256 id, uint256 amount, uint256 burnFrac) external {
        vm.assume(from != address(0));
        amount = bound(amount, 1, type(uint256).max / 1e4);
        burnFrac = bound(burnFrac, 1, 1e4);
        uint256 burnAmount = (amount * burnFrac) / 1e4;

        harness.mint(from, id, amount);

        vm.expectEmit();
        emit Transfer(caller, from, address(0), id, burnAmount);

        vm.prank(caller);
        harness.burn(from, id, burnAmount);

        assertEq(harness.balanceOf(from, id), amount - burnAmount);
    }

    /**
     * ============================================
     * Approve Tests
     * ============================================
     */

    function test_ShouldRevert_Approve_OwnerIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidApprover.selector, address(0)));
        harness.approve(address(0), alice, TOKEN_ID, AMOUNT);
    }

    function test_ShouldRevert_Approve_SpenderIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidSpender.selector, address(0)));
        harness.approve(alice, address(0), TOKEN_ID, AMOUNT);
    }

    function test_Approve() external {
        vm.expectEmit();
        emit Approval(alice, address(this), TOKEN_ID, AMOUNT);

        harness.approve(alice, address(this), TOKEN_ID, AMOUNT);

        assertEq(harness.allowance(alice, address(this), TOKEN_ID), AMOUNT);
    }

    function testFuzz_Approve(address owner, address spender, uint256 id, uint256 amount) external {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));

        vm.expectEmit();
        emit Approval(owner, spender, id, amount);

        harness.approve(owner, spender, id, amount);

        assertEq(harness.allowance(owner, spender, id), amount);
    }

    /**
     * ============================================
     * Set Operator Tests
     * ============================================
     */

    function test_ShouldRevert_SetOperator_OwnerIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidApprover.selector, address(0)));
        harness.setOperator(address(0), alice, true);
    }

    function test_ShouldRevert_SetOperator_SpenderIsZero() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidSpender.selector, address(0)));
        harness.setOperator(alice, address(0), true);
    }

    function test_SetOperator_IsApproved() external {
        vm.expectEmit();
        emit OperatorSet(alice, address(this), true);

        harness.setOperator(alice, address(this), true);
        assertEq(harness.isOperator(alice, address(this)), true);
    }

    function test_SetOperator_RevokeOperator() external {
        harness.setOperator(alice, address(this), true);

        vm.expectEmit();
        emit OperatorSet(alice, address(this), false);

        harness.setOperator(alice, address(this), false);

        assertEq(harness.isOperator(alice, address(this)), false);
    }

    function testFuzz_SetOperator(address owner, address spender, bool approved) external {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));

        vm.expectEmit();
        emit OperatorSet(owner, spender, approved);

        harness.setOperator(owner, spender, approved);

        assertEq(harness.isOperator(owner, spender), approved);
    }

    /**
     * ============================================
     * Transfer Tests
     * ============================================
     */

    function testFuzz_Transfer(address from, address to, uint256 id, uint256 amount) external {
        vm.assume(from != to);
        vm.assume(from != address(0));
        vm.assume(to != address(0));

        harness.mint(from, id, amount);

        vm.expectEmit();
        emit Transfer(from, from, to, id, amount);

        harness.transfer(from, from, to, id, amount);

        assertEq(harness.balanceOf(from, id), 0);
        assertEq(harness.balanceOf(to, id), amount);
    }

    function testFuzz_Transfer_IsOperator(address by, address from, address to, uint256 id, uint256 amount) external {
        vm.assume(from != by);
        vm.assume(from != to);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(by != address(0));

        harness.mint(from, id, amount);
        harness.setOperator(from, by, true);

        vm.expectEmit();
        emit Transfer(by, from, to, id, amount);

        harness.transfer(by, from, to, id, amount);

        assertEq(harness.balanceOf(from, id), 0);
        assertEq(harness.balanceOf(to, id), amount);
    }

    function testFuzz_Transfer_NonOperator_MaxAllowance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(from != by);
        vm.assume(from != to);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(by != address(0));

        amount = bound(amount, 1, type(uint256).max);

        harness.mint(from, id, amount);
        harness.approve(from, by, id, type(uint256).max);

        vm.expectEmit();
        emit Transfer(by, from, to, id, amount);

        harness.transfer(by, from, to, id, amount);

        assertEq(harness.balanceOf(from, id), 0);
        assertEq(harness.balanceOf(to, id), amount);
        assertEq(harness.allowance(from, by, id), type(uint256).max);
    }

    function testFuzz_Transfer_NonOperator_AllowanceLtMax(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 spend
    ) external {
        vm.assume(from != by);
        vm.assume(from != to);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(by != address(0));

        amount = bound(amount, 1, type(uint256).max - 1);
        spend = bound(spend, 1, amount);

        harness.mint(from, id, amount);
        harness.approve(from, by, id, amount);

        vm.expectEmit();
        emit Transfer(by, from, to, id, spend);

        harness.transfer(by, from, to, id, spend);

        assertEq(harness.balanceOf(from, id), amount - spend);
        assertEq(harness.balanceOf(to, id), spend);
        assertEq(harness.allowance(from, by, id), amount - spend);
    }

    function test_ShouldRevert_Transfer_InvalidSender() external {
        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidSender.selector, address(0)));

        harness.transfer(address(0), address(0), alice, TOKEN_ID, AMOUNT);
    }

    function testFuzz_ShouldRevert_NonOperator_InsufficientBalance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 balance
    ) external {
        vm.assume(from != by);
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(by != address(0));

        balance = bound(balance, 1, type(uint256).max - 1);
        amount = bound(amount, balance + 1, type(uint256).max);

        harness.mint(from, id, balance);
        harness.approve(from, by, id, amount);

        vm.expectRevert(
            abi.encodeWithSelector(ERC6909Mod.ERC6909InsufficientBalance.selector, from, balance, amount, id)
        );
        harness.transfer(by, from, to, id, amount);
    }

    function testFuzz_ShouldRevert_Operator_InsufficientBalance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 balance
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(by != address(0));

        balance = bound(balance, 1, type(uint256).max - 1);
        amount = bound(amount, balance + 1, type(uint256).max);

        harness.mint(from, id, balance);
        harness.setOperator(from, by, true);

        vm.expectRevert(
            abi.encodeWithSelector(ERC6909Mod.ERC6909InsufficientBalance.selector, from, balance, amount, id)
        );
        harness.transfer(by, from, to, id, amount);
    }

    function testFuzz_ShouldRevert_NonOperator_AllowanceUnderflow(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 spend
    ) external {
        vm.assume(from != by);
        vm.assume(from != address(0));
        vm.assume(by != address(0));
        vm.assume(to != address(0));

        amount = bound(amount, 1, type(uint256).max - 1);
        vm.assume(spend > amount);

        harness.mint(from, id, amount);
        harness.approve(from, by, id, amount);

        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InsufficientAllowance.selector, by, amount, spend, id));
        harness.transfer(by, from, to, id, spend);
    }

    function testFuzz_ShouldRevert_NonOperator_NoAllowance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(from != by);
        vm.assume(from != address(0));
        vm.assume(by != address(0));
        vm.assume(to != address(0));

        amount = bound(amount, 1, type(uint256).max);

        harness.mint(from, id, amount);

        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InsufficientAllowance.selector, by, 0, amount, id));
        harness.transfer(by, from, to, id, amount);
    }

    function testFuzz_Transfer_SelfTransfer_NonOperator_FiniteAllowance(
        address by,
        address from,
        uint256 id,
        uint256 amount,
        uint256 spend
    ) external {
        vm.assume(from != by);
        vm.assume(from != address(0));
        vm.assume(by != address(0));

        amount = bound(amount, 1, type(uint256).max - 1);
        spend = bound(spend, 1, amount);

        harness.mint(from, id, amount);
        harness.approve(from, by, id, amount);

        vm.expectEmit();
        emit Transfer(by, from, from, id, spend);

        harness.transfer(by, from, from, id, spend);

        assertEq(harness.balanceOf(from, id), amount);
        assertEq(harness.allowance(from, by, id), amount - spend);
    }

    function testFuzz_Transfer_ToZeroAddress_NonOperator_MaxAllowance(
        address by,
        address from,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(from != address(0));
        vm.assume(by != address(0));

        amount = bound(amount, 1, type(uint256).max);

        harness.mint(from, id, amount);
        harness.approve(from, by, id, type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(ERC6909Mod.ERC6909InvalidReceiver.selector, address(0)));
        harness.transfer(by, from, address(0), id, amount);
    }

    function testFuzz_Transfer_ZeroAmount_NonOperator_FiniteAllowance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 allowance
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(by != address(0));
        vm.assume(from != to);

        allowance = bound(allowance, 1, type(uint256).max - 1);

        harness.mint(from, id, allowance);
        harness.approve(from, by, id, allowance);

        vm.expectEmit();
        emit Transfer(by, from, to, id, 0);

        harness.transfer(by, from, to, id, 0);

        assertEq(harness.balanceOf(from, id), allowance);
        assertEq(harness.balanceOf(to, id), 0);
        assertEq(harness.allowance(from, by, id), allowance);
    }
}
