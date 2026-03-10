// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30 <0.9.0;

/* Compose
 * https://compose.diamonds
 */

import {Base_Test} from "test/Base.t.sol";
import {ERC20BridgeableFacet} from "src/token/ERC20/Bridgeable/ERC20BridgeableFacet.sol";
import {AccessControlStorageUtils} from "test/utils/storage/AccessControlStorageUtils.sol";
import {ERC20StorageUtils} from "test/utils/storage/ERC20StorageUtils.sol";

abstract contract ERC20BridgeableFacet_Base_Test is Base_Test {
    /**
     * @dev Role identifier used by ERC20BridgeableFacet (literal "trusted-bridge" as bytes32).
     */
    bytes32 internal constant ERC20_BRIDGE_ROLE = bytes32("trusted-bridge");
    using AccessControlStorageUtils for address;
    using ERC20StorageUtils for address;

    ERC20BridgeableFacet internal facet;

    function setUp() public virtual override {
        Base_Test.setUp();
        facet = new ERC20BridgeableFacet();
        vm.label(address(facet), "ERC20BridgeableFacet");
    }

    function seedTrustedBridge(address bridge) internal {
        address(facet).setHasRole(bridge, ERC20_BRIDGE_ROLE, true);
    }
}
