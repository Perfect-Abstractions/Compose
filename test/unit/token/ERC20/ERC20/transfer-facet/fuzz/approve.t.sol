// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {stdError} from "forge-std/StdError.sol";
import {ERC20TransferFacet_Base_Test} from "../ERC20TransferFacetBase.t.sol";

import {ERC20TransferFacet} from "src/token/ERC20/ERC20/ERC20TransferFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract Approve_ERC20TransferFacet_Fuzz_Unit_Test is ERC20TransferFacet_Base_Test {
    function testFuzz_ShouldRevert_SpenderIsZeroAddress(uint256 value) external {
        vm.expectRevert(abi.encodeWithSelector(ERC20TransferFacet.ERC20InvalidSpender.selector, ADDRESS_ZERO));
        facet.approve(ADDRESS_ZERO, value);
    }

    function testFuzz_Approve(address spender, uint256 value) external whenSpenderNotZeroAddress {
        vm.assume(spender != ADDRESS_ZERO);

        vm.expectEmit(address(facet));
        emit ERC20TransferFacet.Approval(users.alice, spender, value);
        bool result = facet.approve(spender, value);

        assertEq(result, true, "approve failed");
        assertEq(facet.allowance(users.alice, spender), value);
    }
}
