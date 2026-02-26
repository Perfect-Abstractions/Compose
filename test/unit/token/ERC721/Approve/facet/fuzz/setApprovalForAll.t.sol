// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC721ApproveFacet_Base_Test} from "../ERC721ApproveFacetBase.t.sol";
import {ERC721StorageUtils} from "test/utils/storage/ERC721StorageUtils.sol";

import {ERC721ApproveFacet} from "src/token/ERC721/Approve/ERC721ApproveFacet.sol";

/**
 * @dev BTT spec: test/trees/ERC721.tree
 */
contract SetApprovalForAll_ERC721ApproveFacet_Fuzz_Unit_Test is ERC721ApproveFacet_Base_Test {
    using ERC721StorageUtils for address;

    function testFuzz_ShouldRevert_OperatorIsZeroAddress(bool approved) external {
        vm.expectRevert(abi.encodeWithSelector(ERC721ApproveFacet.ERC721InvalidOperator.selector, ADDRESS_ZERO));
        facet.setApprovalForAll(ADDRESS_ZERO, approved);
    }

    function testFuzz_SetApprovalForAll_ApproveTrue(address operator) external whenOperatorNotZeroAddress {
        vm.assume(operator != ADDRESS_ZERO);

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.ApprovalForAll(users.alice, operator, true);
        facet.setApprovalForAll(operator, true);

        assertEq(address(facet).isApprovedForAll(users.alice, operator), true, "isApprovedForAll");
    }

    function testFuzz_SetApprovalForAll_ApproveFalse(address operator) external whenOperatorNotZeroAddress {
        vm.assume(operator != ADDRESS_ZERO);

        // First set to true
        address(facet).setApprovalForAll(users.alice, operator, true);

        vm.expectEmit(address(facet));
        emit ERC721ApproveFacet.ApprovalForAll(users.alice, operator, false);
        facet.setApprovalForAll(operator, false);

        assertEq(address(facet).isApprovedForAll(users.alice, operator), false, "isApprovedForAll");
    }
}
