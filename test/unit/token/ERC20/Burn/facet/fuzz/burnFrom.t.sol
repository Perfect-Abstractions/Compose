// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20BurnFacet_Base_Test} from "../ERC20BurnFacetBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20BurnFacet} from "src/token/ERC20/Burn/ERC20BurnFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract BurnFrom_ERC20BurnFacet_Fuzz_Unit_Test is ERC20BurnFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_SpenderAllowanceLtAmount(
        address account,
        address spender,
        uint256 allowance,
        uint256 value
    ) external {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(spender != ADDRESS_ZERO);
        vm.assume(account != spender);
        allowance = bound(allowance, 0, MAX_UINT256 - 1);
        value = bound(value, allowance + 1, MAX_UINT256);

        address(facet).mint(account, value);
        address(facet).setAllowance(account, spender, allowance);
        vm.stopPrank();
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BurnFacet.ERC20InsufficientAllowance.selector,
                spender,
                allowance,
                value
            )
        );
        facet.burnFrom(account, value);
    }

    function testFuzz_ShouldRevert_AccountBalanceLtAmount(
        address account,
        address spender,
        uint256 balance,
        uint256 value
    ) external {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(spender != ADDRESS_ZERO);
        vm.assume(account != spender);
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);

        address(facet).mint(account, balance);
        address(facet).setAllowance(account, spender, value);
        vm.stopPrank();
        vm.prank(spender);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientBalance.selector, account, balance, value)
        );
        facet.burnFrom(account, value);
    }

    function testFuzz_BurnFrom_FiniteAllowance(
        address account,
        address spender,
        uint256 value,
        uint256 allowance,
        uint256 balance
    ) external {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(spender != ADDRESS_ZERO);
        vm.assume(account != spender);
        value = bound(value, 1, MAX_UINT256 - 1);
        allowance = bound(allowance, value, MAX_UINT256 - 1);
        balance = bound(balance, value, MAX_UINT256);

        address(facet).mint(account, balance);
        address(facet).setAllowance(account, spender, allowance);
        vm.stopPrank();
        vm.prank(spender);

        uint256 beforeTotalSupply = address(facet).totalSupply();
        uint256 beforeBalanceOfAccount = address(facet).balanceOf(account);

        vm.expectEmit(address(facet));
        emit ERC20BurnFacet.Transfer(account, address(0), value);
        facet.burnFrom(account, value);

        assertEq(address(facet).totalSupply(), beforeTotalSupply - value, "totalSupply");
        assertEq(address(facet).balanceOf(account), beforeBalanceOfAccount - value, "balanceOf(account)");
        assertEq(address(facet).allowance(account, spender), allowance - value, "allowance");
    }

    function testFuzz_BurnFrom_InfiniteApproval(
        address account,
        address spender,
        uint256 value,
        uint256 balance
    ) external {
        vm.assume(account != ADDRESS_ZERO);
        vm.assume(spender != ADDRESS_ZERO);
        vm.assume(account != spender);
        value = bound(value, 1, MAX_UINT256);
        balance = bound(balance, value, MAX_UINT256);

        address(facet).mint(account, balance);
        address(facet).setAllowance(account, spender, MAX_UINT256);
        vm.stopPrank();
        vm.prank(spender);

        uint256 beforeTotalSupply = address(facet).totalSupply();
        uint256 beforeBalanceOfAccount = address(facet).balanceOf(account);

        vm.expectEmit(address(facet));
        emit ERC20BurnFacet.Transfer(account, address(0), value);
        facet.burnFrom(account, value);

        assertEq(address(facet).totalSupply(), beforeTotalSupply - value, "totalSupply");
        assertEq(address(facet).balanceOf(account), beforeBalanceOfAccount - value, "balanceOf(account)");
        assertEq(address(facet).allowance(account, spender), MAX_UINT256, "allowance unchanged");
    }
}
