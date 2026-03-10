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
contract BurnBatch_ERC1155BurnMod_Fuzz_Test is ERC1155BurnMod_Base_Test {
    using ERC1155StorageUtils for address;

    function testFuzz_ShouldRevert_BurnBatch_WhenFromIsZeroAddress(
        uint256 id,
        uint256 value
    ) external {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        ids[0] = id;
        values[0] = value;
        vm.expectRevert(abi.encodeWithSelector(ERC1155InvalidSender.selector, address(0)));
        harness.burnBatch(address(0), ids, values);
    }

    function testFuzz_ShouldRevert_BurnBatch_WhenIdsLengthNotEqualToValuesLength(
        address from,
        uint256 idsLen,
        uint256 valuesLen
    ) external {
        vm.assume(from != address(0));
        idsLen = bound(idsLen, 0, 5);
        valuesLen = bound(valuesLen, 0, 5);
        if (idsLen == valuesLen) valuesLen = (valuesLen + 1) % 6;
        uint256[] memory ids = new uint256[](idsLen);
        uint256[] memory values = new uint256[](valuesLen);
        for (uint256 i = 0; i < idsLen; i++) ids[i] = i;
        for (uint256 i = 0; i < valuesLen; i++) values[i] = 1;
        vm.expectRevert(
            abi.encodeWithSelector(ERC1155InvalidArrayLength.selector, idsLen, valuesLen)
        );
        harness.burnBatch(from, ids, values);
    }

    function testFuzz_ShouldDecrementBalances_BurnBatch_WhenPreconditionsHold(
        address from,
        uint256 id0,
        uint256 id1,
        uint256 v0,
        uint256 v1
    ) external {
        vm.assume(from != address(0));
        vm.assume(id0 != id1);
        vm.assume(v0 != type(uint256).max && v1 != type(uint256).max);
        address(harness).setBalanceOf(id0, from, v0);
        address(harness).setBalanceOf(id1, from, v1);
        uint256[] memory ids = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        ids[0] = id0;
        ids[1] = id1;
        values[0] = v0;
        values[1] = v1;
        harness.burnBatch(from, ids, values);
        assertEq(address(harness).balanceOf(id0, from), 0, "balance id0");
        assertEq(address(harness).balanceOf(id1, from), 0, "balance id1");
    }
}
