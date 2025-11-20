// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {ERC6909FacetHarness} from "./harnesses/ERC6909FacetHarness.sol";
import {ERC6909Facet} from "../../../../src/token/ERC6909/ERC6909/ERC6909Facet.sol";

contract ERC6909FacetTest is Test {
    ERC6909FacetHarness internal facet;

    address internal alice;

    uint256 internal constant TOKEN_ID = 72;
    uint256 internal constant AMOUNT = 1e24;

    function setUp() public {
        alice = makeAddr("alice");

        facet = new ERC6909FacetHarness();
    }

    // ============================================
    // Mint Tests
    // ============================================

    function test_Mint() external {
        vm.expectEmit();
        emit ERC6909Facet.Transfer(address(this), address(0), alice, TOKEN_ID, AMOUNT);

        facet.mint(alice, TOKEN_ID, AMOUNT);

        assertEq(facet.balanceOf(alice, TOKEN_ID), AMOUNT);
    }

    function test_ShouldRevert_Mint_BalanceOf_Overflows() external {
        facet.mint(alice, TOKEN_ID, type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);
        facet.mint(alice, TOKEN_ID, 1);
    }

    function testFuzz_Mint(address caller, address to, uint256 id, uint256 amount) external {
        vm.expectEmit();
        emit ERC6909Facet.Transfer(caller, address(0), to, id, amount);

        vm.prank(caller);
        facet.mint(to, id, amount);

        assertEq(facet.balanceOf(to, id), amount);
    }

    // ============================================
    // Approve Tests
    // ============================================

    function test_Approve() external {
        vm.prank(alice);

        vm.expectEmit();
        emit ERC6909Facet.Approval(alice, address(this), TOKEN_ID, AMOUNT);

        facet.approve(address(this), TOKEN_ID, AMOUNT);

        assertEq(facet.allowance(alice, address(this), TOKEN_ID), AMOUNT);
    }

    function testFuzz_Approve(address owner, address spender, uint256 id, uint256 amount) external {
        vm.expectEmit();
        emit ERC6909Facet.Approval(owner, spender, id, amount);

        vm.prank(owner);
        facet.approve(spender, id, amount);

        assertEq(facet.allowance(owner, spender, id), amount);
    }

    // ============================================
    // Set Operator Tests
    // ============================================

    function test_SetOperator_IsApproved() external {
        vm.prank(alice);

        vm.expectEmit();
        emit ERC6909Facet.OperatorSet(alice, address(this), true);

        facet.setOperator(address(this), true);

        assertEq(facet.isOperator(alice, address(this)), true);
    }

    function test_SetOperator_RevokeOperator() external {
        vm.prank(alice);
        facet.setOperator(address(this), true);

        vm.prank(alice);
        vm.expectEmit();
        emit ERC6909Facet.OperatorSet(alice, address(this), false);

        facet.setOperator(address(this), false);

        assertEq(facet.isOperator(alice, address(this)), false);
    }

    function testFuzz_SetOperator(address owner, address spender, bool approved) external {
        vm.expectEmit();
        emit ERC6909Facet.OperatorSet(owner, spender, approved);

        vm.prank(owner);
        facet.setOperator(spender, approved);

        assertEq(facet.isOperator(owner, spender), approved);
    }

    // ============================================
    // Transfer Tests
    // ============================================

    function test_ShouldRevert_Transfer_InsufficientBalance() external {
        vm.expectRevert(stdError.arithmeticError);
        facet.transfer(alice, TOKEN_ID, AMOUNT);
    }

    function test_Transfer() external {
        facet.mint(address(this), TOKEN_ID, AMOUNT);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(address(this), address(this), alice, TOKEN_ID, AMOUNT);

        bool success = facet.transfer(alice, TOKEN_ID, AMOUNT);

        assertTrue(success);
        assertEq(facet.balanceOf(address(this), TOKEN_ID), 0);
        assertEq(facet.balanceOf(alice, TOKEN_ID), AMOUNT);
    }

    function testFuzz_Transfer(address caller, address receiver, uint256 id, uint256 amount) external {
        vm.assume(receiver != caller);

        facet.mint(caller, id, amount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(caller, caller, receiver, id, amount);

        vm.prank(caller);
        bool success = facet.transfer(receiver, id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(caller, id), 0);
        assertEq(facet.balanceOf(receiver, id), amount);
    }

    function testFuzz_Transfer_Self(address caller, uint256 id, uint256 amount) external {
        facet.mint(caller, id, amount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(caller, caller, caller, id, amount);

        vm.prank(caller);
        bool success = facet.transfer(caller, id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(caller, id), amount);
    }

    function testFuzz_Transfer_ToZeroAddress(address caller, uint256 id, uint256 amount) external {
        facet.mint(caller, id, amount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(caller, caller, address(0), id, amount);

        vm.prank(caller);
        bool success = facet.transfer(address(0), id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(caller, id), 0);
        assertEq(facet.balanceOf(address(0), id), amount);
    }

    function testFuzz_Transfer_ZeroAmount(address caller, address receiver, uint256 id, uint256 balance) external {
        vm.assume(receiver != caller);

        balance = bound(balance, 1, type(uint256).max);

        facet.mint(caller, id, balance);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(caller, caller, receiver, id, 0);

        vm.prank(caller);
        bool success = facet.transfer(receiver, id, 0);

        assertTrue(success);
        assertEq(facet.balanceOf(caller, id), balance);
        assertEq(facet.balanceOf(receiver, id), 0);
    }

    // ============================================
    // Transfer From Tests
    // ============================================

    function testFuzz_ShouldRevert_TransferFrom_InsufficientBalance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(by != from);
        vm.assume(from != to);
        vm.assume(amount > 0);

        vm.prank(from);
        facet.approve(by, id, type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);

        vm.prank(by);
        facet.transferFrom(from, to, id, amount);
    }

    function testFuzz_TransferFrom_BySender(address from, address to, uint256 id, uint256 amount) external {
        vm.assume(to != from);
        amount = bound(amount, 1, type(uint256).max);

        facet.mint(from, id, amount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(from, from, to, id, amount);

        vm.prank(from);
        bool success = facet.transferFrom(from, to, id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), 0);
        assertEq(facet.balanceOf(to, id), amount);
    }

    function testFuzz_TransferFrom_IsOperator(address by, address from, address to, uint256 id, uint256 amount)
        external
    {
        vm.assume(from != by);
        vm.assume(from != to);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.setOperator(by, true);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(by, from, to, id, amount);

        vm.prank(by);
        bool success = facet.transferFrom(from, to, id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), 0);
        assertEq(facet.balanceOf(to, id), amount);
        assertEq(facet.allowance(from, by, id), 0);
    }

    function testFuzz_TransferFrom_NonOperator_MaxAllowance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(from != by);
        vm.assume(from != to);

        amount = bound(amount, 1, type(uint256).max);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.approve(by, id, type(uint256).max);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(by, from, to, id, amount);

        vm.prank(by);
        bool success = facet.transferFrom(from, to, id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), 0);
        assertEq(facet.balanceOf(to, id), amount);

        assertEq(facet.allowance(from, by, id), type(uint256).max);
    }

    function testFuzz_TransferFrom_NonOperator_AllowanceLtMax(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 spend
    ) external {
        vm.assume(from != by);
        vm.assume(from != to);

        amount = bound(amount, 1, type(uint256).max - 1);
        spend = bound(spend, 1, amount);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.approve(by, id, amount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(by, from, to, id, spend);

        vm.prank(by);
        bool success = facet.transferFrom(from, to, id, spend);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), amount - spend);
        assertEq(facet.balanceOf(to, id), spend);
        assertEq(facet.allowance(from, by, id), amount - spend);
    }

    function testFuzz_ShouldRevert_TransferFrom_NonOperator_AllowanceUnderflow(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        uint256 spend
    ) external {
        vm.assume(from != by);
        vm.assume(from != to);

        amount = bound(amount, 1, type(uint256).max - 1);
        vm.assume(spend > amount);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.approve(by, id, amount);

        vm.expectRevert(stdError.arithmeticError);

        vm.prank(by);
        facet.transferFrom(from, to, id, spend);
    }

    // Edge cases

    function testFuzz_TransferFrom_SelfTransfer_NonOperator_FiniteAllowance(
        address by,
        address from,
        uint256 id,
        uint256 amount,
        uint256 spend
    ) external {
        vm.assume(from != by);

        amount = bound(amount, 1, type(uint256).max - 1);
        spend = bound(spend, 1, amount);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.approve(by, id, amount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(by, from, from, id, spend);

        vm.prank(by);
        bool success = facet.transferFrom(from, from, id, spend);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), amount);
        assertEq(facet.allowance(from, by, id), amount - spend);
    }

    function testFuzz_TransferFrom_ToZeroAddress_NonOperator_MaxAllowance(
        address by,
        address from,
        uint256 id,
        uint256 amount
    ) external {
        vm.assume(from != by);

        amount = bound(amount, 1, type(uint256).max);

        facet.mint(from, id, amount);

        vm.prank(from);
        facet.approve(by, id, type(uint256).max);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(by, from, address(0), id, amount);

        vm.prank(by);
        bool success = facet.transferFrom(from, address(0), id, amount);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), 0);
        assertEq(facet.balanceOf(address(0), id), amount);
        assertEq(facet.allowance(from, by, id), type(uint256).max);
    }

    function testFuzz_TransferFrom_ZeroAmount_NonOperator_FiniteAllowance(
        address by,
        address from,
        address to,
        uint256 id,
        uint256 allowanceAmount
    ) external {
        vm.assume(from != by);
        vm.assume(from != to);

        allowanceAmount = bound(allowanceAmount, 1, type(uint256).max - 1);

        facet.mint(from, id, allowanceAmount);

        vm.prank(from);
        facet.approve(by, id, allowanceAmount);

        vm.expectEmit();
        emit ERC6909Facet.Transfer(by, from, to, id, 0);

        vm.prank(by);
        bool success = facet.transferFrom(from, to, id, 0);

        assertTrue(success);
        assertEq(facet.balanceOf(from, id), allowanceAmount);
        assertEq(facet.balanceOf(to, id), 0);
        assertEq(facet.allowance(from, by, id), allowanceAmount);
    }
}
