// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC20BridgeableFacet_Base_Test} from "test/unit/token/ERC20/Bridgeable/ERC20BridgeableFacetBase.t.sol";
import {ERC20BridgeableFacet} from "src/token/ERC20/Bridgeable/ERC20BridgeableFacet.sol";

/**
 *  @dev BTT spec: test/trees/ERC20.tree
 */
contract CheckTokenBridge_ERC20BridgeableFacet_Fuzz_Unit_Test is ERC20BridgeableFacet_Base_Test {
    function testFuzz_ShouldRevert_WhenCallerIsZeroAddress() external {
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidBridgeAccount.selector, ADDRESS_ZERO)
        );
        facet.checkTokenBridge(ADDRESS_ZERO);
    }

    function testFuzz_ShouldRevert_WhenCallerDoesNotHaveBridgeRole(address account) external {
        vm.assume(account != ADDRESS_ZERO);
        vm.expectRevert(
            abi.encodeWithSelector(ERC20BridgeableFacet.ERC20InvalidBridgeAccount.selector, account)
        );
        facet.checkTokenBridge(account);
    }

    function testFuzz_ShouldNotRevert_WhenCallerHasBridgeRole(address bridge) external {
        vm.assume(bridge != ADDRESS_ZERO);
        seedTrustedBridge(bridge);
        facet.checkTokenBridge(bridge);
    }
}
