// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {Test} from "forge-std/Test.sol";
import {ERC20BurnFacet} from "../../../../src/token/ERC20/ERC20/ERC20BurnFacet.sol";
import {ERC20BurnFacetHarness} from "./harnesses/ERC20BurnFacetHarness.sol";

contract ERC20BurnFacetTest is Test {
    ERC20BurnFacetHarness public token;

    address public alice;
    address public bob;
    address public charlie;

    uint256 constant INITIAL_SUPPLY = 1000000e18;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        token = new ERC20BurnFacetHarness();
        token.mint(alice, INITIAL_SUPPLY);
    }

    function test_Burn() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), amount);
        token.burn(amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_Burn_EntireBalance() public {
        vm.prank(alice);
        token.burn(INITIAL_SUPPLY);

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
    }

    function testFuzz_Burn(uint256 amount) public {
        vm.assume(amount <= INITIAL_SUPPLY);

        vm.prank(alice);
        token.burn(amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_RevertWhen_BurnInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.burn(amount);
    }

    function test_RevertWhen_BurnFromZeroBalance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientBalance.selector, bob, 0, 1));
        token.burn(1);
    }

    function test_BurnFrom() public {
        uint256 amount = 100e18;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), amount);
        token.burnFrom(alice, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_BurnFrom_PartialAllowance() public {
        uint256 allowanceAmount = 200e18;
        uint256 burnAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        token.burnFrom(alice, burnAmount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - burnAmount);
        assertEq(token.allowance(alice, bob), allowanceAmount - burnAmount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - burnAmount);
    }

    function testFuzz_BurnFrom(uint256 approval, uint256 amount) public {
        vm.assume(approval <= INITIAL_SUPPLY);
        vm.assume(amount <= approval);

        vm.prank(alice);
        token.approve(bob, approval);

        vm.prank(bob);
        token.burnFrom(alice, amount);

        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.allowance(alice, bob), approval - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);
    }

    function test_BurnFrom_UnlimitedAllowance() public {
        uint256 amount = 100e18;
        uint256 maxAllowance = type(uint256).max;

        /**
         * Set unlimited allowance
         */
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        /**
         * Perform first burn
         */
        vm.prank(bob);
        token.burnFrom(alice, amount);

        /**
         * Check that allowance remains unchanged (unlimited)
         */
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - amount);

        /**
         * Perform second burn to verify allowance is still unlimited
         */
        vm.prank(bob);
        token.burnFrom(alice, amount);

        /**
         * Check that allowance is still unchanged (unlimited)
         */
        assertEq(token.allowance(alice, bob), maxAllowance);
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - 2 * amount);
        assertEq(token.totalSupply(), INITIAL_SUPPLY - 2 * amount);
    }

    function test_BurnFrom_UnlimitedAllowance_MultipleBurns() public {
        uint256 maxAllowance = type(uint256).max;
        uint256 burnAmount = 50e18;
        uint256 numBurns = 10;

        /**
         * Set unlimited allowance
         */
        vm.prank(alice);
        token.approve(bob, maxAllowance);

        /**
         * Perform multiple burns
         */
        for (uint256 i = 0; i < numBurns; i++) {
            vm.prank(bob);
            token.burnFrom(alice, burnAmount);

            /**
             * Verify allowance remains unlimited after each burn
             */
            assertEq(token.allowance(alice, bob), maxAllowance);
        }

        /**
         * Verify final balances and total supply
         */
        assertEq(token.balanceOf(alice), INITIAL_SUPPLY - (burnAmount * numBurns));
        assertEq(token.totalSupply(), INITIAL_SUPPLY - (burnAmount * numBurns));
    }

    function test_RevertWhen_BurnFromInsufficientAllowance() public {
        uint256 allowanceAmount = 50e18;
        uint256 burnAmount = 100e18;

        vm.prank(alice);
        token.approve(bob, allowanceAmount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientAllowance.selector, bob, allowanceAmount, burnAmount)
        );
        token.burnFrom(alice, burnAmount);
    }

    function test_RevertWhen_BurnFromInsufficientBalance() public {
        uint256 amount = INITIAL_SUPPLY + 1;

        vm.prank(alice);
        token.approve(bob, amount);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientBalance.selector, alice, INITIAL_SUPPLY, amount)
        );
        token.burnFrom(alice, amount);
    }

    function test_RevertWhen_BurnFromNoAllowance() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientAllowance.selector, bob, 0, 100e18));
        token.burnFrom(alice, 100e18);
    }
}
