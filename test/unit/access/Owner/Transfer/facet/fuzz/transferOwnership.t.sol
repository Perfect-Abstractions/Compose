// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerTransfer_Base_Test} from "test/unit/access/Owner/Transfer/OwnerTransferBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerTransferFacet} from "src/access/Owner/Transfer/OwnerTransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract TransferOwnership_OwnerTransferFacet_Fuzz_Unit_Test is OwnerTransfer_Base_Test {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    OwnerTransferFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new OwnerTransferFacet();
        vm.label(address(facet), "OwnerTransferFacet");
        seedOwner(address(facet), users.admin);
    }

    function testFuzz_ShouldUpdateOwner_TransferOwnership_WhenCallerIsOwner(address newOwner) external {
        vm.prank(users.admin);
        facet.transferOwnership(newOwner);

        assertEq(OwnerStorageUtils.owner(address(facet)), newOwner, "owner");
    }

    function testFuzz_ShouldEmitOwnershipTransferred_TransferOwnership_WhenCallerIsOwner(address newOwner) external {
        vm.expectEmit(address(facet));
        emit OwnershipTransferred(users.admin, newOwner);

        vm.prank(users.admin);
        facet.transferOwnership(newOwner);
    }

    function testFuzz_ShouldSetOwnerToZero_TransferOwnership_WhenNewOwnerIsZero() external {
        vm.prank(users.admin);
        facet.transferOwnership(address(0));

        assertEq(OwnerStorageUtils.owner(address(facet)), address(0), "owner");
    }

    function testFuzz_ShouldLeaveOwnerUnchanged_TransferOwnership_WhenNewOwnerIsSelf(address owner_) external {
        vm.assume(owner_ != address(0));
        seedOwner(address(facet), owner_);

        vm.prank(owner_);
        facet.transferOwnership(owner_);

        assertEq(OwnerStorageUtils.owner(address(facet)), owner_, "owner");
    }

    function testFuzz_ShouldRevert_TransferOwnership_WhenCallerIsNotOwner(address caller, address newOwner) external {
        vm.assume(caller != users.admin);

        vm.prank(caller);
        vm.expectRevert(OwnerTransferFacet.OwnerUnauthorizedAccount.selector);
        facet.transferOwnership(newOwner);
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerTransferFacet.transferOwnership.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
