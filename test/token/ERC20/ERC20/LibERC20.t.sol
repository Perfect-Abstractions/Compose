// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

import {Test} from "forge-std/Test.sol";
import {LibERC20Harness} from "./harnesses/LibERC20Harness.sol";
import {LibERC20} from "../../../../src/token/ERC20/ERC20/LibERC20.sol";

contract LibERC20Test is Test {
    LibERC20Harness public harness;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        harness = new LibERC20Harness();
        harness.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    /**
     * ============================================
     * Metadata Tests
     * ============================================
     */

    function test_Name() public view {
        assertEq(harness.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(harness.symbol(), TOKEN_SYMBOL);
    }

    function test_Decimals() public view {
        assertEq(harness.decimals(), TOKEN_DECIMALS);
    }

    function test_InitialTotalSupply() public view {
        assertEq(harness.totalSupply(), 0);
    }

    /**
     * ============================================
     * Mint Tests
     * ============================================
     */

    function test_Mint() public {
        uint256 amount = 100e18;

        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, amount);
        harness.mint(alice, amount);

        assertEq(harness.balanceOf(alice), amount);
        assertEq(harness.totalSupply(), amount);
    }

    function test_Mint_Multiple() public {
        harness.mint(alice, 100e18);
        harness.mint(bob, 200e18);
        harness.mint(alice, 50e18);

        assertEq(harness.balanceOf(alice), 150e18);
        assertEq(harness.balanceOf(bob), 200e18);
        assertEq(harness.totalSupply(), 350e18);
    }

    function testFuzz_Mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount < type(uint256).max / 2);

        harness.mint(to, amount);

        assertEq(harness.balanceOf(to), amount);
        assertEq(harness.totalSupply(), amount);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InvalidReceiver.selector, address(0)));
        harness.mint(address(0), 100e18);
    }

    /**
     * ============================================
     * Burn Tests
     * ============================================
     */

    function test_Burn() public {
        uint256 mintAmount = 100e18;
        uint256 burnAmount = 30e18;

        harness.mint(alice, mintAmount);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), burnAmount);
        harness.burn(alice, burnAmount);

        assertEq(harness.balanceOf(alice), mintAmount - burnAmount);
        assertEq(harness.totalSupply(), mintAmount - burnAmount);
    }

    function test_Burn_EntireBalance() public {
        uint256 amount = 100e18;

        harness.mint(alice, amount);
        harness.burn(alice, amount);

        assertEq(harness.balanceOf(alice), 0);
        assertEq(harness.totalSupply(), 0);
    }

    function testFuzz_Burn(address account, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(account != address(0));
        vm.assume(mintAmount < type(uint256).max / 2);
        vm.assume(burnAmount <= mintAmount);

        harness.mint(account, mintAmount);
        harness.burn(account, burnAmount);

        assertEq(harness.balanceOf(account), mintAmount - burnAmount);
        assertEq(harness.totalSupply(), mintAmount - burnAmount);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InvalidSender.selector, address(0)));
        harness.burn(address(0), 100e18);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        harness.mint(alice, 50e18);

        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InsufficientBalance.selector, alice, 50e18, 100e18));
        harness.burn(alice, 100e18);
    }

    function test_RevertWhen_BurnZeroBalance() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InsufficientBalance.selector, alice, 0, 1));
        harness.burn(alice, 1);
    }

    /**
     * ============================================
     * Transfer Tests
     * ============================================
     */

    function test_Transfer() public {
        uint256 amount = 100e18;

        harness.mint(alice, 200e18);

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, amount);
        harness.transfer(bob, amount);

        assertEq(harness.balanceOf(alice), 100e18);
        assertEq(harness.balanceOf(bob), amount);
    }

    function test_Transfer_ToSelf() public {
        uint256 amount = 100e18;

        harness.mint(alice, amount);

        vm.prank(alice);
        harness.transfer(alice, amount);

        assertEq(harness.balanceOf(alice), amount);
    }

    function test_Transfer_ZeroAmount() public {
        harness.mint(alice, 100e18);

        vm.prank(alice);
        harness.transfer(bob, 0);

        assertEq(harness.balanceOf(alice), 100e18);
        assertEq(harness.balanceOf(bob), 0);
    }

    function testFuzz_Transfer(uint256 balance, uint256 amount) public {
        vm.assume(balance < type(uint256).max / 2);
        vm.assume(amount <= balance);

        harness.mint(alice, balance);

        vm.prank(alice);
        harness.transfer(bob, amount);

        assertEq(harness.balanceOf(alice), balance - amount);
        assertEq(harness.balanceOf(bob), amount);
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        harness.mint(alice, 100e18);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InvalidReceiver.selector, address(0)));
        harness.transfer(address(0), 100e18);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        harness.mint(alice, 50e18);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InsufficientBalance.selector, alice, 50e18, 100e18));
        harness.transfer(bob, 100e18);
    }

    function test_RevertWhen_MintOverflowsRecipient() public {
        uint256 maxBalance = type(uint256).max - 100;

        /**
         * Mint near-max tokens to alice
         */
        harness.mint(alice, maxBalance);

        /**
         * Try to mint more, which would overflow
         */
        vm.expectRevert(); // Arithmetic overflow
        harness.mint(alice, 200);
    }

    /**
     * ============================================
     * Approve Tests
     * ============================================
     */

    function test_Approve() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, amount);
        harness.approve(bob, amount);

        assertEq(harness.allowance(alice, bob), amount);
    }

    function test_Approve_UpdateExisting() public {
        vm.startPrank(alice);
        harness.approve(bob, 100e18);
        harness.approve(bob, 200e18);
        vm.stopPrank();

        assertEq(harness.allowance(alice, bob), 200e18);
    }

    function test_Approve_ToZero() public {
        vm.startPrank(alice);
        harness.approve(bob, 100e18);
        harness.approve(bob, 0);
        vm.stopPrank();

        assertEq(harness.allowance(alice, bob), 0);
    }

    function testFuzz_Approve(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        vm.prank(alice);
        harness.approve(spender, amount);

        assertEq(harness.allowance(alice, spender), amount);
    }

    function test_RevertWhen_ApproveZeroAddressSpender() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InvalidSpender.selector, address(0)));
        harness.approve(address(0), 100e18);
    }

    /**
     * ============================================
     * TransferFrom Tests
     * ============================================
     */

    function test_TransferFrom() public {
        uint256 amount = 100e18;

        harness.mint(alice, 200e18);

        vm.prank(alice);
        harness.approve(bob, amount);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, charlie, amount);
        harness.transferFrom(alice, charlie, amount);

        assertEq(harness.balanceOf(alice), 100e18);
        assertEq(harness.balanceOf(charlie), amount);
        assertEq(harness.allowance(alice, bob), 0);
    }

    function test_TransferFrom_PartialAllowance() public {
        uint256 allowanceAmount = 200e18;
        uint256 transferAmount = 100e18;

        harness.mint(alice, 300e18);

        vm.prank(alice);
        harness.approve(bob, allowanceAmount);

        vm.prank(bob);
        harness.transferFrom(alice, charlie, transferAmount);

        assertEq(harness.balanceOf(alice), 200e18);
        assertEq(harness.balanceOf(charlie), transferAmount);
        assertEq(harness.allowance(alice, bob), allowanceAmount - transferAmount);
    }

    function testFuzz_TransferFrom(uint256 balance, uint256 approval, uint256 amount) public {
        vm.assume(balance < type(uint256).max / 2);
        vm.assume(approval <= balance);
        vm.assume(amount <= approval);

        harness.mint(alice, balance);

        vm.prank(alice);
        harness.approve(bob, approval);

        vm.prank(bob);
        harness.transferFrom(alice, charlie, amount);

        assertEq(harness.balanceOf(alice), balance - amount);
        assertEq(harness.balanceOf(charlie), amount);
        assertEq(harness.allowance(alice, bob), approval - amount);
    }

    function test_RevertWhen_TransferFromZeroAddressSender() public {
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InvalidSender.selector, address(0)));
        harness.transferFrom(address(0), bob, 100e18);
    }

    function test_RevertWhen_TransferFromZeroAddressReceiver() public {
        harness.mint(alice, 100e18);

        vm.prank(alice);
        harness.approve(bob, 100e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InvalidReceiver.selector, address(0)));
        harness.transferFrom(alice, address(0), 100e18);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        uint256 allowanceAmount = 50e18;
        uint256 transferAmount = 100e18;

        harness.mint(alice, 200e18);

        vm.prank(alice);
        harness.approve(bob, allowanceAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(LibERC20.ERC20InsufficientAllowance.selector, bob, allowanceAmount, transferAmount)
        );
        harness.transferFrom(alice, charlie, transferAmount);
    }

    function test_RevertWhen_TransferFromInsufficientBalance() public {
        uint256 balance = 50e18;
        uint256 amount = 100e18;

        harness.mint(alice, balance);

        vm.prank(alice);
        harness.approve(bob, amount);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InsufficientBalance.selector, alice, balance, amount));
        harness.transferFrom(alice, charlie, amount);
    }

    function test_RevertWhen_TransferFromNoAllowance() public {
        harness.mint(alice, 100e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LibERC20.ERC20InsufficientAllowance.selector, bob, 0, 100e18));
        harness.transferFrom(alice, charlie, 100e18);
    }

    /**
     * ============================================
     * Integration Tests
     * ============================================
     */

    function test_MintTransferBurn_Flow() public {
        harness.mint(alice, 1000e18);
        assertEq(harness.totalSupply(), 1000e18);

        vm.prank(alice);
        harness.transfer(bob, 300e18);

        vm.prank(bob);
        harness.transfer(charlie, 100e18);

        harness.burn(alice, 200e18);

        assertEq(harness.balanceOf(alice), 500e18);
        assertEq(harness.balanceOf(bob), 200e18);
        assertEq(harness.balanceOf(charlie), 100e18);
        assertEq(harness.totalSupply(), 800e18);
    }

    function test_ApproveTransferFromBurn_Flow() public {
        harness.mint(alice, 1000e18);

        vm.prank(alice);
        harness.approve(bob, 500e18);

        vm.prank(bob);
        harness.transferFrom(alice, charlie, 200e18);

        assertEq(harness.allowance(alice, bob), 300e18);

        harness.burn(charlie, 50e18);

        assertEq(harness.balanceOf(alice), 800e18);
        assertEq(harness.balanceOf(charlie), 150e18);
        assertEq(harness.totalSupply(), 950e18);
    }
}
