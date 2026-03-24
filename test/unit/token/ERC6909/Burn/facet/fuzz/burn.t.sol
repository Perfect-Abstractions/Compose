// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909BurnFacet_Base_Test} from "test/unit/token/ERC6909/Burn/ERC6909BurnFacetBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909BurnFacet} from "src/token/ERC6909/Burn/ERC6909BurnFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Burn_ERC6909BurnFacet_Fuzz_Test is ERC6909BurnFacet_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_RevertWhen_InsufficientBalance_Burn(uint256 id, uint256 balance, uint256 amount) external {
        vm.assume(balance < type(uint256).max);
        amount = bound(amount, balance + 1, type(uint256).max);
        seedBalance(address(facet), users.alice, id, balance);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909BurnFacet.ERC6909InsufficientBalance.selector, users.alice, balance, amount, id
            )
        );
        facet.burn(id, amount);
    }

    function testFuzz_ShouldDecrementAndEmit_Burn(uint256 id, uint256 amount) external {
        vm.assume(amount != 0);
        vm.assume(amount < type(uint256).max);
        seedBalance(address(facet), users.alice, id, amount);
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectEmit(true, true, true, true);
        emit ERC6909BurnFacet.Transfer(users.alice, users.alice, address(0), id, amount);
        facet.burn(id, amount);
        assertEq(address(facet).balanceOf(users.alice, id), 0, "balance");
    }

    function testFuzz_RevertWhen_FromZero_BurnFrom(uint256 id, uint256 amount) external {
        vm.stopPrank();
        vm.prank(users.alice);
        vm.expectRevert(abi.encodeWithSelector(ERC6909BurnFacet.ERC6909InvalidSender.selector, address(0)));
        facet.burnFrom(address(0), id, amount);
    }

    function testFuzz_RevertWhen_InsufficientAllowance_BurnFrom(
        address from,
        uint256 id,
        uint256 balance,
        uint256 allowanceAmt,
        uint256 burnAmt
    ) external {
        vm.assume(from != address(0));
        vm.assume(from != users.bob);
        balance = bound(balance, 1, type(uint256).max - 1);
        allowanceAmt = bound(allowanceAmt, 0, balance - 1);
        burnAmt = bound(burnAmt, allowanceAmt + 1, balance);

        seedBalance(address(facet), from, id, balance);
        seedAllowance(address(facet), from, users.bob, id, allowanceAmt);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909BurnFacet.ERC6909InsufficientAllowance.selector, users.bob, allowanceAmt, burnAmt, id
            )
        );
        facet.burnFrom(from, id, burnAmt);
    }

    function test_ShouldNotDecreaseAllowance_BurnFrom_WhenAllowanceMax() external {
        uint256 id = 2;
        uint256 amt = 30;
        seedBalance(address(facet), users.alice, id, amt);
        seedAllowance(address(facet), users.alice, users.bob, id, type(uint256).max);
        vm.stopPrank();
        vm.prank(users.bob);
        facet.burnFrom(users.alice, id, amt);
        assertEq(address(facet).allowance(users.alice, users.bob, id), type(uint256).max, "allowance");
    }

    function testFuzz_ShouldDecreaseAllowanceAndBurn_BurnFrom(
        address from,
        uint256 id,
        uint256 balance,
        uint256 allowanceAmt,
        uint256 burnAmt
    ) external {
        vm.assume(from != address(0));
        vm.assume(from != users.bob);
        balance = bound(balance, 2, type(uint256).max / 2);
        burnAmt = bound(burnAmt, 1, balance);
        allowanceAmt = bound(allowanceAmt, burnAmt, balance);

        seedBalance(address(facet), from, id, balance);
        seedAllowance(address(facet), from, users.bob, id, allowanceAmt);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectEmit(true, true, true, true);
        emit ERC6909BurnFacet.Transfer(users.bob, from, address(0), id, burnAmt);
        facet.burnFrom(from, id, burnAmt);

        assertEq(address(facet).balanceOf(from, id), balance - burnAmt, "balance");
        assertEq(address(facet).allowance(from, users.bob, id), allowanceAmt - burnAmt, "allowance");
    }
}
