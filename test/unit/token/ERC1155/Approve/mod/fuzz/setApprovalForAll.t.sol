// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC1155ApproveMod_Base_Test} from "test/unit/token/ERC1155/Approve/ERC1155ApproveModBase.t.sol";
import {ERC1155StorageUtils} from "test/utils/storage/ERC1155StorageUtils.sol";
import "src/token/ERC1155/Approve/ERC1155ApproveMod.sol";

/**
 * @dev BTT spec: test/trees/ERC1155.tree
 */
contract SetApprovalForAll_ERC1155ApproveMod_Fuzz_Test is ERC1155ApproveMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_SetApprovalForAll_WhenOperatorIsZeroAddress(
        address user,
        bool approved
    ) external {
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidOperator.selector, address(0)));
        harness.setApprovalForAll(user, address(0), approved);
    }

    function testFuzz_ShouldSetApprovalAndEmit_SetApprovalForAll_WhenOperatorNotZero(
        address user,
        address operator,
        bool approved
    ) external {
        vm.assume(operator != address(0));
        vm.expectEmit(address(harness));
        emit ApprovalForAll(user, operator, approved);
        harness.setApprovalForAll(user, operator, approved);
        assertEq(address(harness).isApprovedForAll(user, operator), approved, "isApprovedForAll");
    }
}
