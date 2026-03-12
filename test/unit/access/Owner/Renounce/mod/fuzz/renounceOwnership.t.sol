// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerRenounce_Base_Test} from "test/unit/access/Owner/Renounce/OwnerRenounceBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerCoreModHarness} from "test/utils/harnesses/access/Owner/OwnerCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract RenounceOwnership_OwnerMod_Fuzz_Unit_Test is OwnerRenounce_Base_Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    OwnerCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new OwnerCoreModHarness();
        vm.label(address(harness), "OwnerCoreModHarness");
        seedOwner(address(harness), users.admin);
    }

    function testFuzz_ShouldSetOwnerToZero_RenounceOwnership_WhenCallerIsOwner() external {
        vm.prank(users.admin);
        harness.renounceOwnership();

        assertEq(OwnerStorageUtils.owner(address(harness)), address(0), "owner");
        assertEq(harness.owner(), address(0), "owner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_RenounceOwnership_WhenCallerIsOwner() external {
        vm.expectEmit(address(harness));
        emit OwnershipTransferred(users.admin, address(0));

        vm.prank(users.admin);
        harness.renounceOwnership();
    }

    function testFuzz_ShouldRevert_RenounceOwnership_WhenCallerIsNotOwner(address caller) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.renounceOwnership();
    }
}
