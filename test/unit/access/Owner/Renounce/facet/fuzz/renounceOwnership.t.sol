// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerRenounce_Base_Test} from "test/unit/access/Owner/Renounce/OwnerRenounceBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerRenounceFacet} from "src/access/Owner/Renounce/OwnerRenounceFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract RenounceOwnership_OwnerRenounceFacet_Fuzz_Unit_Test is OwnerRenounce_Base_Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    OwnerRenounceFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new OwnerRenounceFacet();
        vm.label(address(facet), "OwnerRenounceFacet");
        seedOwner(address(facet), users.admin);
    }

    function testFuzz_ShouldSetOwnerToZero_RenounceOwnership_WhenCallerIsOwner() external {
        vm.prank(users.admin);
        facet.renounceOwnership();

        assertEq(OwnerStorageUtils.owner(address(facet)), address(0), "owner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_RenounceOwnership_WhenCallerIsOwner() external {
        vm.expectEmit(address(facet));
        emit OwnershipTransferred(users.admin, address(0));

        vm.prank(users.admin);
        facet.renounceOwnership();
    }

    function testFuzz_ShouldRevert_RenounceOwnership_WhenCallerIsNotOwner(address caller) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(OwnerRenounceFacet.OwnerUnauthorizedAccount.selector);
        facet.renounceOwnership();
    }
}
