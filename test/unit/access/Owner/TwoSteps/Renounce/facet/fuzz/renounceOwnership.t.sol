// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTwoStepRenounce_Base_Test} from "test/unit/access/Owner/TwoSteps/Renounce/OwnerTwoStepRenounceBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTwoStepRenounceFacet} from "src/access/Owner/TwoSteps/Renounce/OwnerTwoStepRenounceFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract RenounceOwnership_OwnerTwoStepRenounceFacet_Fuzz_Unit_Test is OwnerTwoStepRenounce_Base_Test {
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    OwnerTwoStepRenounceFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new OwnerTwoStepRenounceFacet();
        vm.label(address(facet), "OwnerTwoStepRenounceFacet");
        seedOwner(address(facet), users.admin);
    }

    function testFuzz_ShouldSetOwnerAndPendingToZero_RenounceOwnership_WhenCallerIsOwner() external {
        seedPendingOwner(address(facet), users.bob);

        vm.prank(users.admin);
        facet.renounceOwnership();

        assertEq(OwnerStorageUtils.owner(address(facet)), address(0), "owner");
        assertEq(OwnerStorageUtils.pendingOwner(address(facet)), address(0), "pendingOwner");
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
        vm.expectRevert(OwnerTwoStepRenounceFacet.OwnerUnauthorizedAccount.selector);
        facet.renounceOwnership();
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerTwoStepRenounceFacet.renounceOwnership.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
