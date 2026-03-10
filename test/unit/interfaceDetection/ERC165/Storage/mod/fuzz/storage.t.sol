// SPDX-License-Identifier: MIT
pragma solidity >=0.8.30;

/* Compose
 * https://compose.diamonds
 */

import {ERC165Mod_Base_Test} from "test/unit/interfaceDetection/ERC165/ERC165ModBase.t.sol";

/**
 * @dev BTT spec: test/trees/ERC165.tree
 */
contract Storage_ERC165Mod_Fuzz_Unit_Test is ERC165Mod_Base_Test {
    function test_ShouldUseExpectedSlot_WhenReadingStoragePosition() external view {
        assertEq(harness.getStoragePosition(), keccak256("erc165"));
    }

    function test_ShouldStoreMappingValue_WhenRegisteringInterface() external {
        bytes32 storageSlot = keccak256("erc165");
        harness.registerInterface(IERC721_INTERFACE_ID);

        bytes32 mappingSlot = keccak256(abi.encode(IERC721_INTERFACE_ID, storageSlot));
        bytes32 storedValue = vm.load(address(harness), mappingSlot);

        assertEq(uint256(storedValue), 1);
    }

    function test_ShouldMatchRawStorage_AfterRegistration() external {
        harness.registerInterface(IERC721_INTERFACE_ID);

        assertEq(harness.supportsInterface(IERC721_INTERFACE_ID), harness.getStorageValue(IERC721_INTERFACE_ID));
    }

    function test_ShouldMatchRawStorage_AfterMultipleRegistrations() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.registerInterface(IERC20_INTERFACE_ID);
        harness.registerInterface(IERC1155_INTERFACE_ID);

        assertEq(harness.supportsInterface(IERC721_INTERFACE_ID), harness.getStorageValue(IERC721_INTERFACE_ID));
        assertEq(harness.supportsInterface(IERC20_INTERFACE_ID), harness.getStorageValue(IERC20_INTERFACE_ID));
        assertEq(harness.supportsInterface(IERC1155_INTERFACE_ID), harness.getStorageValue(IERC1155_INTERFACE_ID));
    }

    function test_ShouldMatchRawStorage_AfterUnregistration() external {
        harness.registerInterface(IERC721_INTERFACE_ID);
        harness.forceSetInterface(IERC721_INTERFACE_ID, false);

        assertEq(harness.supportsInterface(IERC721_INTERFACE_ID), harness.getStorageValue(IERC721_INTERFACE_ID));
    }

    function testFuzz_ShouldMatchRawStorage_AfterFuzzedState(bytes4 interfaceId, bool shouldSupport) external {
        harness.forceSetInterface(interfaceId, shouldSupport);

        assertEq(harness.supportsInterface(interfaceId), harness.getStorageValue(interfaceId));
        assertEq(harness.supportsInterface(interfaceId), shouldSupport);
    }
}

