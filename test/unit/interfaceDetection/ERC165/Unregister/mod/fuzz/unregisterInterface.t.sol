// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Mod_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165ModBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract UnregisterInterface_ERC165Mod_Fuzz_Unit_Test is ERC165Mod_Base_Test {
    function test_ShouldUnsetSupport_WhenUnregisteringRegisteredInterface() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.forceSetInterface(IERC721_INTERFACE_ID, false);

        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldNotAffectOtherInterfaces_WhenUnregisteringOne() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);

        harness.forceSetInterface(IERC721_INTERFACE_ID, false);

        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
        assertTrue(harness.supportsInterface(IERC20_INTERFACE_ID));
    }

    function test_ShouldTrackRegisterUnregisterCycle() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.registerInterface(IERC721_INTERFACE_ID);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function test_ShouldForceSetTrueAndFalse() external {
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.forceSetInterface(IERC721_INTERFACE_ID, true);
        assertTrue(harness.supportsInterface(IERC721_INTERFACE_ID));

        harness.forceSetInterface(IERC721_INTERFACE_ID, false);
        assertFalse(harness.supportsInterface(IERC721_INTERFACE_ID));
    }

    function testFuzz_ShouldUnsetSupport_WhenForceUnregistering(bytes4 interfaceId) external {
        harness.registerInterface(interfaceId);
        harness.forceSetInterface(interfaceId, false);

        assertFalse(harness.supportsInterface(interfaceId));
    }

    function testFuzz_ShouldKeepOtherInterfaceSupport_WhenUnregisteringOne(
        bytes4 interfaceId1,
        bytes4 interfaceId2,
        bytes4 interfaceId3
    ) external {
        vm.assume(interfaceId1 != interfaceId2);
        vm.assume(interfaceId1 != interfaceId3);
        vm.assume(interfaceId2 != interfaceId3);

        harness.registerInterface(interfaceId1);
        harness.registerInterface(interfaceId2);

        assertTrue(harness.supportsInterface(interfaceId1));
        assertTrue(harness.supportsInterface(interfaceId2));

        harness.forceSetInterface(interfaceId1, false);

        assertFalse(harness.supportsInterface(interfaceId1));
        assertTrue(harness.supportsInterface(interfaceId2));

        harness.registerInterface(interfaceId3);

        assertFalse(harness.supportsInterface(interfaceId1));
        assertTrue(harness.supportsInterface(interfaceId2));
        assertTrue(harness.supportsInterface(interfaceId3));
    }
}

