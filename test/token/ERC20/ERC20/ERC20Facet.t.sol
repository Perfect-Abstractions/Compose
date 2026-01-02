// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test} from "forge-std/Test.sol";
import {ERC20Facet} from "../../../../src/token/ERC20/ERC20/ERC20Facet.sol";
import {ERC20FacetHarness} from "./harnesses/ERC20FacetHarness.sol";

contract ERC20FacetTest is Test {
    ERC20FacetHarness public token;

    address public alice;
    address public bob;
    address public charlie;

    string constant TOKEN_NAME = "Test Token";
    string constant TOKEN_SYMBOL = "TEST";
    uint8 constant TOKEN_DECIMALS = 18;
    uint256 constant INITIAL_SUPPLY = 1000000e18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new ERC20FacetHarness();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
        token.mint(alice, INITIAL_SUPPLY);
    }

    /**
     * ============================================
     * Metadata Tests
     * ============================================
     */

    function test_Name() public view {
        assertEq(token.name(), TOKEN_NAME);
    }

    function test_Symbol() public view {
        assertEq(token.symbol(), TOKEN_SYMBOL);
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), TOKEN_DECIMALS);
    }

    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), INITIAL_SUPPLY);
    }

    function test_BalanceOf() public view {
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    /**
     * ============================================
     * Transfer Tests
     * ============================================
     */

    function test_Transfer() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, bob, amount);
        bool success = token.transfer(bob, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(bob), amount);
    }

    function test_Transfer_ReturnsTrue() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        bool result = token.transfer(bob, amount);

        assertTrue(result, "transfer should return true");
    }

    function test_Transfer_ToSelf() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
    }

    function test_Transfer_ZeroAmount() public {
        vm.prank(alice);
        token.transfer(bob, 0);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        assertEq(token.balanceOf(bob), 0);
    }

    function test_Transfer_EntireBalance() public {
        vm.prank(alice);
        token.transfer(bob, INITIAL_SUPPLY);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), INITIAL_SUPPLY);
    }

    function testFuzz_Transfer(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount <= INITIAL_SUPPLY);

        vm.prank(alice);
        token.transfer(to, amount);

        if (to == alice) {
            assertEq(token.balanceOf(alice), INITIAL_SUPPLY);
        } else {
            assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
            assertEq(token.balanceOf(to), amount);
        }
    }

    function test_RevertWhen_TransferToZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidReceiver.selector, address(0)));
        token.transfer(address(0), 100e18);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.transfer(bob, amount);
    }

    function test_RevertWhen_TransferFromZeroBalance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, bob, 0, 1));
        token.transfer(alice, 1);
    }

    function test_RevertWhen_TransferOverflowsRecipient() public {
        uint256 maxBalance = type(uint256).max - 100;

        /**
         * Mint near-max tokens to bob
         */
        token.mint(bob, maxBalance);

        /**
         * Alice tries to transfer 200 tokens to bob, which would overflow
         */
        vm.prank(alice);
        vm.expectRevert(); // Arithmetic overflow
        token.transfer(bob, 200);
    }

    /**
     * ============================================
     * Approval Tests
     * ============================================
     */

    function test_Approve() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, amount);
        bool success = token.approve(bob, amount);

        assertTrue(success);
        assertEq(token.allowance(alice, bob), amount);
    }

    function test_Approve_ReturnsTrue() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        bool result = token.approve(bob, amount);

        assertTrue(result, "approve should return true");
    }

    function test_Approve_UpdateExisting() public {
        vm.startPrank(alice);
        token.approve(bob, 100e18);
        token.approve(bob, 200e18);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob), 200e18);
    }

    function test_Approve_ZeroAmount() public {
        vm.startPrank(alice);
        token.approve(bob, 100e18);
        token.approve(bob, 0);
        vm.stopPrank();

        assertEq(token.allowance(alice, bob), 0);
    }

    function testFuzz_Approve(address spender, uint256 amount) public {
        vm.assume(spender != address(0));

        vm.prank(alice);
        token.approve(spender, amount);

        assertEq(token.allowance(alice, spender), amount);
    }

    function test_RevertWhen_ApproveZeroAddressSpender() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidSpender.selector, address(0)));
        token.approve(address(0), 100e18);
    }

    /**
     * ============================================
     * TransferFrom Tests
     * ============================================
     */

    function test_TransferFrom() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, charlie, amount);
        bool success = token.transferFrom(alice, charlie, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(charlie), amount);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_TransferFrom_ReturnsTrue() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        bool result = token.transferFrom(alice, charlie, amount);

        assertTrue(result, "transferFrom should return true");
    }

    function test_TransferFrom_PartialAllowance() public {
        uint256 allowanceAmount = 200e18;
        uint256 transferAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        token.transferFrom(alice, charlie, transferAmount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - transferAmount);
        assertEq(token.balanceOf(charlie), transferAmount);
        assertEq(token.allowance(alice, bob), allowanceAmount - transferAmount);
    }

    function testFuzz_TransferFrom(uint256 approval, uint256 amount) public {
        vm.assume(approval <= INITIAL_SUPPLY);
        vm.assume(amount <= approval);

        vm.prank(alice);
        token.approve(bob, approval);

        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(charlie), amount);
        assertEq(token.allowance(alice, bob), approval - amount);
    }

    function test_TransferFrom_UnlimitedAllowance() public {
        uint256 amount = 100e18;
        uint256 maxAllowance = type(uint256).max;

        /**
         * Set unlimited allowance
         */
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        /**
         * Perform first transfer
         */
        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        /**
         * Check that allowance remains unchanged (unlimited)
         */
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.balanceOf(charlie), amount);

        /**
         * Perform second transfer to verify allowance is still unlimited
         */
        vm.prank(bob);
        token.transferFrom(alice, charlie, amount);

        /**
         * Check that allowance is still unchanged (unlimited)
         */
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - 2 * amount);
        assertEq(token.balanceOf(charlie), 2 * amount);
    }

    function test_TransferFrom_UnlimitedAllowance_MultipleTransfers() public {
        uint256 maxAllowance = type(uint256).max;
        uint256 transferAmount = 50e18;
        uint256 numTransfers = 10;

        /**
         * Set unlimited allowance
         */
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        /**
         * Perform multiple transfers
         */
        for (uint256 i = 0; i < numTransfers; i++) {
            vm.prank(bob);
            token.transferFrom(alice, charlie, transferAmount);

            /**
             * Verify allowance remains unlimited after each transfer
             */
            assertEq(token.allowance(alice, bob), maxAllowance);
        }

        /**
         * Verify final balances
         */
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - (transferAmount * numTransfers));
        assertEq(token.balanceOf(charlie), transferAmount * numTransfers);
    }

    function test_RevertWhen_TransferFromZeroAddressSender() public {
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidSender.selector, address(0)));
        token.transferFrom(address(0), bob, 100e18);
    }

    function test_RevertWhen_TransferFromZeroAddressReceiver() public {
        vm.prank(alice);
        token.approve(bob, 100e18);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InvalidReceiver.selector, address(0)));
        token.transferFrom(alice, address(0), 100e18);
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        uint256 allowanceAmount = 50e18;
        uint256 transferAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientAllowance.selector, bob, allowanceAmount, transferAmount)
        );
        token.transferFrom(alice, charlie, transferAmount);
    }

    function test_RevertWhen_TransferFromInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20Facet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.transferFrom(alice, charlie, amount);
    }

    function test_RevertWhen_TransferFromNoAllowance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20Facet.ERC20InsufficientAllowance.selector, bob, 0, 100e18));
        token.transferFrom(alice, charlie, 100e18);
    }
}
