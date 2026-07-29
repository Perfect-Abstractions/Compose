// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";
import {Base_Test} from "test/Base.t.sol";
import {ERC20BridgeableModHarness} from "test/utils/harnesses/token/ERC20/ERC20BridgeableModHarness.sol";

contract TemporalExpiry_ERC20BridgeableMod_Test is Base_Test {
    bytes32 internal constant ERC20_BRIDGE_ROLE = bytes32("trusted-bridge");
    using AccessControlStorageUtils for address;
    using ERC20StorageUtils for address;

    ERC20BridgeableModHarness internal bridgeHarness;

    function setUp() public override {
        super.setUp();
        bridgeHarness = new ERC20BridgeableModHarness();
        vm.label(address(bridgeHarness), "ERC20BridgeableModHarness");
    }

    function test_ShouldRevert_CrosschainMint_WhenBridgeRoleExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(bridgeHarness).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(bridgeHarness).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", ERC20_BRIDGE_ROLE, users.alice)
        );
        bridgeHarness.crosschainMint(users.bob, 1000);
    }

    function test_ShouldSucceed_CrosschainMint_WhenBridgeRoleNotExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(bridgeHarness).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(bridgeHarness).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        bridgeHarness.crosschainMint(users.bob, 1000);

        assertEq(address(bridgeHarness).balanceOf(users.bob), 1000);
    }

    function test_ShouldRevert_CrosschainBurn_WhenBridgeRoleExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(bridgeHarness).setBalance(users.bob, 1000);

        address(bridgeHarness).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(bridgeHarness).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", ERC20_BRIDGE_ROLE, users.alice)
        );
        bridgeHarness.crosschainBurn(users.bob, 500);
    }

    function test_ShouldSucceed_CrosschainBurn_WhenBridgeRoleNotExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(bridgeHarness).setBalance(users.bob, 1000);
        address(bridgeHarness).setTotalSupply(1000);

        address(bridgeHarness).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(bridgeHarness).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        bridgeHarness.crosschainBurn(users.bob, 500);

        assertEq(address(bridgeHarness).balanceOf(users.bob), 500);
    }

    function test_ShouldRevert_CheckTokenBridge_WhenBridgeRoleExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(bridgeHarness).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(bridgeHarness).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(expiry + 1);

        vm.expectRevert(
            abi.encodeWithSignature("AccessControlRoleExpired(bytes32,address)", ERC20_BRIDGE_ROLE, users.alice)
        );
        bridgeHarness.checkTokenBridge(users.alice);
    }

    function test_ShouldSucceed_CheckTokenBridge_WhenBridgeRoleNotExpired() external {
        uint256 expiry = block.timestamp + 1 hours;

        address(bridgeHarness).setHasRole(users.alice, ERC20_BRIDGE_ROLE, true);
        address(bridgeHarness).setRoleExpiry(users.alice, ERC20_BRIDGE_ROLE, expiry);

        vm.warp(block.timestamp + 30 minutes);

        bridgeHarness.checkTokenBridge(users.alice);
    }
}
