// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerData_Base_Test} from "test/unit/access/Owner/Data/OwnerDataBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerCoreModHarness} from "test/utils/harnesses/access/Owner/OwnerCoreModHarness.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract Data_OwnerMod_Fuzz_Unit_Test is OwnerData_Base_Test {
    OwnerCoreModHarness internal harness;

    function setUp() public override {
        super.setUp();
        harness = new OwnerCoreModHarness();
        vm.label(address(harness), "OwnerCoreModHarness");
    }

    function testFuzz_ShouldReturnStoredOwner_Owner_WhenOwnerHasBeenSet(address owner_) external {
        seedOwner(address(harness), owner_);

        assertEq(harness.owner(), owner_, "owner");
    }

    function testFuzz_ShouldReturnZero_Owner_WhenOwnerHasBeenRenounced() external {
        seedOwner(address(harness), address(0));

        assertEq(harness.owner(), address(0), "owner");
    }

    function testFuzz_ShouldNotRevert_RequireOwner_WhenCallerIsOwner(address owner_) external {
        vm.assume(owner_ != address(0));
        seedOwner(address(harness), owner_);

        vm.prank(owner_);
        harness.requireOwner();
    }

    function testFuzz_ShouldRevert_RequireOwner_WhenCallerIsNotOwner(address owner_, address caller) external {
        vm.assume(owner_ != address(0));
        vm.assume(caller != owner_);
        seedOwner(address(harness), owner_);

        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSignature("OwnerUnauthorizedAccount()"));
        harness.requireOwner();
    }
}
