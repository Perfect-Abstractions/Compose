// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155TransferMod_Base_Test} from "test/unit/token/ERC1155/Transfer/ERC1155TransferModBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import "src/token/ERC1155/Transfer/ERC1155TransferMod.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract SafeTransferFrom_ERC1155TransferMod_Fuzz_Test is ERC1155TransferMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenToIsZeroAddress(
        address from,
        address operator,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        address(harness).setBalanceOf(id, from, value);
        address(harness).setApprovedForAll(from, operator, true);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidReceiver.selector, address(0)));
        harness.safeTransferFrom(from, address(0), id, value, operator);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenFromIsZeroAddress(address to, uint256 id, uint256 value)
        external
    {
        vm.assume(to != address(0));
        vm.assume(to.code.length == 0);
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidSender.selector, address(0)));
        harness.safeTransferFrom(address(0), to, id, value, users.alice);
    }

    function testFuzz_ShouldRevert_SafeTransferFrom_WhenNotApprovedAndNotOwner(
        address from,
        address to,
        address operator,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(to != from);
        vm.assume(to.code.length == 0);
        vm.assume(operator != from);
        vm.assume(value != type(uint256).max);
        address(harness).setBalanceOf(id, from, value);
        vm.expectRevert(abi.encodeWithSelector(ERC1155MissingApprovalForAll.selector, operator, from));
        harness.safeTransferFrom(from, to, id, value, operator);
    }

    function testFuzz_ShouldUpdateBalances_SafeTransferFrom_WhenPreconditionsHold(
        address from,
        address to,
        address operator,
        uint256 id,
        uint256 value
    ) external {
        vm.assume(from != address(0));
        vm.assume(to != address(0));
        vm.assume(from != to);
        vm.assume(to.code.length == 0);
        vm.assume(operator == from || operator != from);
        vm.assume(value != type(uint256).max);
        address(harness).setBalanceOf(id, from, value);
        if (operator != from) {
            address(harness).setApprovedForAll(from, operator, true);
        }
        harness.safeTransferFrom(from, to, id, value, operator);
        assertEq(address(harness).balanceOf(id, from), 0, "from balance");
        assertEq(address(harness).balanceOf(id, to), value, "to balance");
    }
}
