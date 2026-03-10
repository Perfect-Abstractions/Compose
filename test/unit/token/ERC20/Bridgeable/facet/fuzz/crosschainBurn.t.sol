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
contract CrosschainBurn_ERC20BridgeableFacet_Fuzz_Unit_Test is ERC20BridgeableFacet_Base_Test {
    using ERC20StorageUtils for address;

    function testFuzz_ShouldRevert_WhenCallerNotTrustedBridge(address from, uint256 value) external {
        vm.assume(from != ADDRESS_ZERO);
        address(facet).mint(from, value);
        address bridge = users.admin;
        seedTrustedBridge(bridge);
        vm.assume(from != bridge);
        vm.stopPrank();
        vm.prank(from);
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlUnauthorizedAccount.selector, from, ERC20_BRIDGE_ROLE
            )
        );
        facet.crosschainBurn(from, value);
    }

    function testFuzz_ShouldRevert_WhenFromIsZeroAddress(uint256 value) external {
        seedTrustedBridge(users.admin);
        vm.stopPrank();
        vm.prank(users.admin);
        vm.expectRevert(abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidReceiver.selector, ADDRESS_ZERO));
        facet.crosschainBurn(ADDRESS_ZERO, value);
    }

    function testFuzz_ShouldRevert_WhenInsufficientBalance(address from, uint256 balance, uint256 value) external {
        vm.assume(from != ADDRESS_ZERO);
        vm.assume(balance < MAX_UINT256);
        value = bound(value, balance + 1, MAX_UINT256);
        address(facet).mint(from, balance);
        seedTrustedBridge(users.admin);
        vm.stopPrank();
        vm.prank(users.admin);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InsufficientBalance.selector, from, balance, value)
        );
        facet.crosschainBurn(from, value);
    }

    function testFuzz_CrosschainBurn(address from, uint256 value) external {
        vm.assume(from != ADDRESS_ZERO);
        value = bound(value, 1, MAX_UINT256 - 1);
        address(facet).mint(from, value);
        seedTrustedBridge(users.admin);
        uint256 beforeTotalSupply = address(facet).totalSupply();
        uint256 beforeBalanceOfFrom = address(facet).balanceOf(from);
        vm.stopPrank();
        vm.prank(users.admin);
        vm.expectEmit(address(facet));
        emit ERC20BridgeableFacet.Transfer(from, address(0), value);
        vm.expectEmit(address(facet));
        emit ERC20BridgeableFacet.CrosschainBurn(from, value, users.admin);
        facet.crosschainBurn(from, value);
        assertEq(address(facet).totalSupply(), beforeTotalSupply - value, "totalSupply");
        assertEq(address(facet).balanceOf(from), beforeBalanceOfFrom - value, "balanceOf(from)");
    }
}
