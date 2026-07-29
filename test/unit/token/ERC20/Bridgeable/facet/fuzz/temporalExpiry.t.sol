// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {ERC20BridgeableFacet_Base_Test} from "test/unit/token/ERC20/Bridgeable/ERC20BridgeableFacetBase.t.sol";
import {ERC20BridgeableFacet} from "src/token/ERC20/Bridgeable/ERC20BridgeableFacet.sol";

contract TemporalExpiry_ERC20BridgeableFacet_Test is ERC20BridgeableFacet_Base_Test {
    using AccessControlStorageUtils for address;
    using ERC20StorageUtils for address;

    function test_ShouldRevert_CrosschainMint_WhenBridgeRoleExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(facet).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(facet).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlRoleExpired.selector, ERC20_BRIDGE_ROLE, users.alice
            )
        );
        facet.crosschainMint(users.bob, 1000);
    }

    function test_ShouldSucceed_CrosschainMint_WhenBridgeRoleNotExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(facet).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(facet).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        facet.crosschainMint(users.bob, 1000);

        assertEq(address(facet).balanceOf(users.bob), 1000);
    }

    function test_ShouldRevert_CrosschainBurn_WhenBridgeRoleExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(facet).setBalance(users.bob, 1000);

        address(facet).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(facet).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlRoleExpired.selector, ERC20_BRIDGE_ROLE, users.alice
            )
        );
        facet.crosschainBurn(users.bob, 500);
    }

    function test_ShouldSucceed_CrosschainBurn_WhenBridgeRoleNotExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(facet).setBalance(users.bob, 1000);
        address(facet).setTotalSupply(1000);

        address(facet).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(facet).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        facet.crosschainBurn(users.bob, 500);

        assertEq(address(facet).balanceOf(users.bob), 500);
    }

    function test_ShouldRevert_CheckTokenBridge_WhenBridgeRoleExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(facet).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(facet).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20BridgeableFacet.AccessControlRoleExpired.selector, ERC20_BRIDGE_ROLE, users.alice
            )
        );
        facet.checkTokenBridge(users.alice);
    }

    function test_ShouldSucceed_CheckTokenBridge_WhenBridgeRoleNotExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(facet).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(facet).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        facet.checkTokenBridge(users.alice);
    }
}
