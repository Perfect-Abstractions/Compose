// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20BridgeableFacet_Base_Test} from "test/unit/token/ERC20/Bridgeable/ERC20BridgeableFacetBase.t.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20BridgeableFacet} from "src/token/ERC20/Bridgeable/ERC20BridgeableFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract CrosschainMint_ERC20BridgeableFacet_Fuzz_Unit_Test is ERC20BridgeableFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_WhenCallerNotTrustedBridge(address to, uint256 value) external {
        vm.assume(to != ADDRESS_ZERO);
        address bridge = users.admin;
        seedTrustedBridge(bridge);
        vm.assume(to != bridge);
        vm.stopPrank();
        vm.prank(to);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlUnauthorizedAccount.selector, to, ERC20_BRIDGE_ROLE
            )
        );
        facet.crosschainMint(to, value);
    }

    function testFuzz_ShouldRevert_WhenAccountIsZeroAddress(uint256 value) external {
        seedTrustedBridge(users.admin);
        vm.stopPrank();
        vm.prank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidReceiver.selector, ADDRESS_ZERO));
        facet.crosschainMint(ADDRESS_ZERO, value);
    }

    function testFuzz_CrosschainMint(address to, uint256 value) external {
        vm.assume(to != ADDRESS_ZERO);
        value = bound(value, 1, MAX_UINT256 - 1);
        seedTrustedBridge(users.admin);
        uint256 beforeTotalSupply = address(facet).totalSupply();
        uint256 beforeBalanceOfTo = address(facet).balanceOf(to);
        vm.stopPrank();
        vm.prank(users.admin);
        vm.expectEmit(address(facet));
        emit ERC20BridgeableFacet.Transfer(address(0), to, value);
        vm.expectEmit(address(facet));
        emit ERC20BridgeableFacet.CrosschainMint(to, value, users.admin);
        facet.crosschainMint(to, value);
        assertEq(address(facet).totalSupply(), beforeTotalSupply + value, "totalSupply");
        assertEq(address(facet).balanceOf(to), beforeBalanceOfTo + value, "balanceOf(to)");
    }
}
