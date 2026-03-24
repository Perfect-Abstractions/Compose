// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC6909BurnMod_Base_Test} from "test/unit/token/ERC6909/Burn/ERC6909BurnModBase.t.sol";
import {ERC6909StorageUtils} from "test/utils/storage/ERC6909StorageUtils.sol";
import {ERC6909BurnFacet} from "src/token/ERC6909/Burn/ERC6909BurnFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC6909.tree
 */
contract Burn_ERC6909BurnMod_Fuzz_Test is ERC6909BurnMod_Base_Test {
    using ERC6909StorageUtils for address;

    function testFuzz_ShouldDecrement_Burn(uint256 id, uint256 amount) external {
        vm.assume(amount != 0);
        vm.assume(amount < type(uint256).max);
        seedBalance(address(harness), users.alice, id, amount);
        vm.stopPrank();
        vm.prank(users.alice);
        harness.burn(id, amount);
        assertEq(address(harness).balanceOf(users.alice, id), 0, "balance");
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

        seedBalance(address(harness), from, id, balance);
        seedAllowance(address(harness), from, users.bob, id, allowanceAmt);

        vm.stopPrank();
        vm.prank(users.bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC6909BurnFacet.ERC6909InsufficientAllowance.selector, users.bob, allowanceAmt, burnAmt, id
            )
        );
        harness.burnFrom(from, id, burnAmt);
    }
}
