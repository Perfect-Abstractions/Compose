// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {OwnerData_Base_Test} from "test/unit/access/Owner/Data/OwnerDataBase.t.sol";
import {OwnerStorageUtils} from "test/utils/storage/OwnerStorageUtils.sol";
import {OwnerDataFacet} from "src/access/Owner/Data/OwnerDataFacet.sol";

/**
 *  @dev BTT spec: test/trees/Owner.tree
 */
contract Data_OwnerDataFacet_Fuzz_Unit_Test is OwnerData_Base_Test {
    OwnerDataFacet internal facet;

    function setUp() public override {
        super.setUp();
        facet = new OwnerDataFacet();
        vm.label(address(facet), "OwnerDataFacet");
    }

    function testFuzz_ShouldReturnStoredOwner_Owner_WhenOwnerHasBeenSet(address owner_) external {
        seedOwner(address(facet), owner_);

        assertEq(facet.owner(), owner_, "owner");
    }

    function testFuzz_ShouldReturnZero_Owner_WhenOwnerHasBeenRenounced() external {
        seedOwner(address(facet), address(0));

        assertEq(facet.owner(), address(0), "owner");
    }

    function test_ShouldReturnSelectors_ExportSelectors() external view {
        bytes memory selectors = facet.exportSelectors();
        bytes memory expected = abi.encodePacked(OwnerDataFacet.owner.selector);
        assertEq(selectors, expected, "exportSelectors");
    }
}
