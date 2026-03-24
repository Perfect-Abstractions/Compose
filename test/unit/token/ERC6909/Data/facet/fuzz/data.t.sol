// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909DataFacet_Base_Test} from "test/unit/token/ERC6909/Data/ERC6909DataFacetBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Data_ERC6909DataFacet_Fuzz_Test is ERC6909DataFacet_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_ShouldReturnBalance_BalanceOf_WhenOwnerAndIdQueried(address owner, uint256 id, uint256 value)
        external
    {
        vm.assume(value != type(uint256).max);
        seedBalance(address(facet), owner, id, value);
        assertEq(facet.balanceOf(owner, id), value, "balanceOf");
    }

    function testFuzz_ShouldReturnAllowance_Allowance_WhenQueried(
        address owner,
        address spender,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(value != type(uint256).max);
        seedAllowance(address(facet), owner, spender, id, value);
        assertEq(facet.allowance(owner, spender, id), value, "allowance");
    }

    function testFuzz_ShouldReturnFalse_IsOperator_WhenNotSet(address owner, address spender) external view {
        assertEq(facet.isOperator(owner, spender), false, "isOperator");
    }

    function testFuzz_ShouldReturnTrue_IsOperator_WhenSet(address owner, address spender) external {
        vm.assume(owner != address(0));
        vm.assume(spender != address(0));
        seedIsOperator(address(facet), owner, spender, true);
        assertEq(facet.isOperator(owner, spender), true, "isOperator");
    }
}
