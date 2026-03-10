// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20DataFacet_Base_Test} from "test/unit/token/ERC20/Data/ERC20DataFacetBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20DataFacet} from "src/token/ERC20/Data/ERC20DataFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Data_ERC20DataFacet_Fuzz_Unit_Test is ERC20DataFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldReturnBalance_BalanceOf_WhenAccountQueried(address account, uint256 value) external {
        vm.assume(value != type(uint256).max);
        address(facet).setBalance(account, value);

        assertEq(facet.balanceOf(account), value, "balanceOf");
    }

    function testFuzz_ShouldReturnZero_BalanceOf_WhenAccountIsZeroAddress() external view {
        assertEq(facet.balanceOf(address(0)), 0, "balanceOf zero address");
    }

    function testFuzz_ShouldReturnTotalSupply_WhenQueried(uint256 supply) external {
        vm.assume(supply != type(uint256).max);
        address(facet).setTotalSupply(supply);

        assertEq(facet.totalSupply(), supply, "totalSupply");
    }

    function testFuzz_ShouldReturnAllowance_WhenOwnerAndSpenderQueried(address owner, address spender, uint256 amount)
        external
    {
        vm.assume(owner != ADDRESS_ZERO);
        vm.assume(spender != ADDRESS_ZERO);
        vm.assume(amount != type(uint256).max);
        address(facet).setAllowance(owner, spender, amount);

        assertEq(facet.allowance(owner, spender), amount, "allowance");
    }
}
