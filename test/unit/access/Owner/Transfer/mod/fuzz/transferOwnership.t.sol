// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTransfer_Base_Test} from "test/unit/access/Owner/Transfer/OwnerTransferBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerCoreModHarness} from "test/harnesses/access/Owner/OwnerCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract TransferOwnership_OwnerMod_Fuzz_Unit_Test is OwnerTransfer_Base_Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    OwnerCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new OwnerCoreModHarness();
        vm.label(address(harness), "OwnerCoreModHarness");
        seedOwner(address(harness), users.admin);
    }

    function testFuzz_ShouldUpdateOwner_TransferOwnership_WhenCallerIsOwner(address newOwner) external {
        vm.prank(users.admin);
        harness.transferOwnership(newOwner);

        assertEq(OwnerStorageUtils.owner(address(harness)), newOwner, "owner");
        assertEq(harness.owner(), newOwner, "owner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_TransferOwnership_WhenCallerIsOwner(address newOwner) external {
        vm.expectEmit(address(harness));
        emit OwnershipTransferred(users.admin, newOwner);

        vm.prank(users.admin);
        harness.transferOwnership(newOwner);
    }

    function testFuzz_ShouldSetOwnerToZero_TransferOwnership_WhenNewOwnerIsZero() external {
        vm.prank(users.admin);
        harness.transferOwnership(address(0));

        assertEq(harness.owner(), address(0), "owner");
    }

    function testFuzz_ShouldLeaveOwnerUnchanged_TransferOwnership_WhenNewOwnerIsSelf(address owner_) external {
        vm.assume(owner_ != address(0));
        seedOwner(address(harness), owner_);

        vm.prank(owner_);
        harness.transferOwnership(owner_);

        assertEq(harness.owner(), owner_, "owner");
    }

    function testFuzz_ShouldRevert_TransferOwnership_WhenCallerIsNotOwner(address caller, address newOwner) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.transferOwnership(newOwner);
    }
}
