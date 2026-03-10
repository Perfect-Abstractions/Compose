// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155BurnMod_Base_Test} from "test/unit/token/ERC1155/Burn/ERC1155BurnModBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import "src/token/ERC1155/Burn/ERC1155BurnMod.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract Burn_ERC1155BurnMod_Fuzz_Test is ERC1155BurnMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_Burn_WhenFromIsZeroAddress(uint256 id, uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidSender.selector, address(0)));
        harness.burn(address(0), id, value);
    }

    function testFuzz_ShouldRevert_Burn_WhenInsufficientBalance(
        address from,
        uint256 id,
        uint256 balance,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(balance < type(uint256).max);
        value = bound(value, balance + 1, type(uint256).max);
        address(harness).setBalanceOf(id, from, balance);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InsufficientBalance.selector, from, balance, value, id));
        harness.burn(from, id, value);
    }

    function testFuzz_ShouldDecrementBalance_Burn_WhenPreconditionsHold(address from, uint256 id, uint256 value)
        external
    {
        vm.assume(from != address(0));
        vm.assume(value != type(uint256).max);
        address(harness).setBalanceOf(id, from, value);
        harness.burn(from, id, value);
        assertEq(address(harness).balanceOf(id, from), 0, "balance");
    }
}
