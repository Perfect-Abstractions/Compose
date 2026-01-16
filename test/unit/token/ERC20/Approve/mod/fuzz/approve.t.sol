// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20ApproveModHarness} from "test/harnesses/token/ERC20/ERC20ApproveModHarness.sol";

import "src/token/ERC20/Approve/ERC20ApproveMod.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Approve_ERC20ApproveMod_Fuzz_Unit_Test is Base_Test {
    using ERC20StorageUtils for address;

    ERC20ApproveModHarness internal harness;

    function setUp() public override {
        Base_Test.setUp();
        harness = new ERC20ApproveModHarness();
    }

    function testFuzz_ShouldRevert_SpenderIsZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20InvalidSpender.selector, ADDRESS_ZERO));
        harness.approve(ADDRESS_ZERO, value);
    }

    function testFuzz_Approve(address spender, uint256 value) external whenSpenderNotZeroAddress {
        vm.assume(spender != ADDRESS_ZERO);

        vm.expectEmit(address(harness));
        emit Approval(users.alice, spender, value);
        bool result = harness.approve(spender, value);

        assertEq(result, true, "approve failed");
        assertEq(address(harness).allowance(users.alice, spender), value);
    }
}
