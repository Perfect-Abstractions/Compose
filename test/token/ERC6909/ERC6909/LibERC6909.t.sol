// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {LibERC6909Harness} from "./harnesses/LibERC6909Harness.sol";
import {LibERC6909} from "../../../../src/token/ERC6909/ERC6909/LibERC6909.sol";

contract LibERC6909Test is Test {
    LibERC6909Harness internal harness;

    address internal alice;

    uint256 internal constant TOKEN_ID = 72;
    uint256 internal constant MINT_AMOUNT = 1e24;

    function setUp() public {
        alice = makeAddr("alice");

        harness = new LibERC6909Harness();
    }

    // ============================================
    // Mint Tests
    // ============================================

    function test_Mint() external {
        vm.expectEmit();
        emit LibERC6909.Transfer(address(this), address(0), alice, TOKEN_ID, MINT_AMOUNT);

        harness.mint(alice, TOKEN_ID, MINT_AMOUNT);

        assertEq(harness.balanceOf(alice, TOKEN_ID), MINT_AMOUNT);
    }

    function test_ShouldRevert_Mint_BalanceOf_Overflows() external {
        harness.mint(alice, TOKEN_ID, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        harness.mint(alice, TOKEN_ID, 1);
    }

    function testFuzz_Mint(address caller, address to, uint256 id, uint256 amount) external {
        vm.expectEmit();
        emit LibERC6909.Transfer(caller, address(0), to, id, amount);

        vm.prank(caller);
        harness.mint(to, id, amount);

        assertEq(harness.balanceOf(to, id), amount);
    }
}
