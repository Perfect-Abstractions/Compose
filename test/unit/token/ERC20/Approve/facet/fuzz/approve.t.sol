// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

import {ERC20ApproveFacet} from "src/token/ERC20/Approve/ERC20ApproveFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Approve_ERC20ApproveFacet_Fuzz_Unit_Test is Base_Test {
    using ERC20StorageUtils for address;

    ERC20ApproveFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20ApproveFacet();
        vm.label(address(facet), "ERC20ApproveFacet");
    }

    function testFuzz_ShouldRevert_SpenderIsZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20ApproveFacet.ERC20InvalidSpender.selector, ADDRESS_ZERO));
        facet.approve(ADDRESS_ZERO, value);
    }

    function testFuzz_Approve(address spender, uint256 value) external whenSpenderNotZeroAddress {
        vm.assume(spender != ADDRESS_ZERO);

        vm.expectEmit(address(facet));
        emit ERC20ApproveFacet.Approval(users.alice, spender, value);
        bool result = facet.approve(spender, value);

        assertEq(result, true, "approve failed");
        assertEq(address(facet).allowance(users.alice, spender), value);
    }
}

