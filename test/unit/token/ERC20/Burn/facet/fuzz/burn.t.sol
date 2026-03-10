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
contract Burn_ERC20BurnFacet_Fuzz_Unit_Test is ERC20BurnFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_CallerInsufficientBalance(address caller, uint256 balance, uint256 value)
        external
    {
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);

        address(facet).mint(caller, balance);
        vm.stopPrank();
        vm.prank(caller);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BurnFacet.ERC20InsufficientBalance.selector, caller, balance, value)
        );
        facet.burn(value);
    }

    function testFuzz_Burn(address caller, uint256 balance, uint256 value)
        external
        whenAccountNotZeroAddress
        givenWhenAccountBalanceGEBurnAmount
    {
        vm.assume(caller != ADDRESS_ZERO);
        balance = bound(balance, 1, MAX_UINT256);
        value = bound(value, 1, balance);

        address(facet).mint(caller, balance);
        uint256 beforeTotalSupply = address(facet).totalSupply();
        uint256 beforeBalanceOfCaller = address(facet).balanceOf(caller);

        vm.expectEmit(address(facet));
        emit ERC20BurnFacet.Transfer(caller, address(0), value);
        vm.stopPrank();
        vm.prank(caller);
        facet.burn(value);

        assertEq(address(facet).totalSupply(), beforeTotalSupply - value, "totalSupply");
        assertEq(address(facet).balanceOf(caller), beforeBalanceOfCaller - value, "balanceOf(caller)");
    }
}
